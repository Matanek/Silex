#include <algorithm>
#include <atomic>
#include <cerrno>
#include <cstdint>
#include <cstdlib>
#include <cwchar>
#include <cstring>
#include <limits>
#include <mutex>
#include <string>
#include <system_error>
#include <thread>
#include <utility>
#include <vector>

#include "Unicode/utf8proc/utf8proc.h"

#if defined(_WIN32)
#include <windows.h>
#else
#include <fcntl.h>
#include <signal.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>
#if defined(__APPLE__)
#include <crt_externs.h>
#else
extern char** environ;
#endif
#endif

struct SilexNative_STD_Subprocess_NativeCommand {
    std::string executable;
    bool hasCurrentDirectory = false;
    std::string currentDirectory;
    bool inheritEnvironment = true;
    std::int64_t maximumOutputBytes = 0;
    std::vector<std::string> arguments;
    std::vector<std::pair<std::string, std::string>> environmentSets;
    std::vector<std::string> environmentRemovals;
    std::vector<std::uint8_t> input;
};

struct SilexNative_STD_Subprocess_NativeOutput {
    std::int64_t statusKind = 1;
    std::int64_t statusCode = 0;
    std::vector<std::uint8_t> standardOutput;
    std::vector<std::uint8_t> standardError;
};

struct SilexNative_STD_Subprocess_NativeFailure {
    std::int64_t kind;
    char* detail_bytes;
    std::int64_t detail_length;
};

#define SILEX_SUBPROCESS_RESULT(NAME, SUCCESS)                                      \
    enum SilexNative_STD_Subprocess_##NAME##ResultTag {                             \
        SilexNative_STD_Subprocess_##NAME##ResultTag_success = 0,                   \
        SilexNative_STD_Subprocess_##NAME##ResultTag_failure = 1                    \
    };                                                                               \
    struct SilexNative_STD_Subprocess_##NAME##Result {                              \
        SilexNative_STD_Subprocess_##NAME##ResultTag tag;                           \
        SUCCESS                                                                      \
        SilexNative_STD_Subprocess_NativeFailure failure_value;                     \
    }

SILEX_SUBPROCESS_RESULT(native_create, SilexNative_STD_Subprocess_NativeCommand* success_value;);
SILEX_SUBPROCESS_RESULT(native_add_argument, );
SILEX_SUBPROCESS_RESULT(native_set_environment, );
SILEX_SUBPROCESS_RESULT(native_remove_environment, );
SILEX_SUBPROCESS_RESULT(native_set_input, );
SILEX_SUBPROCESS_RESULT(native_run, SilexNative_STD_Subprocess_NativeOutput* success_value;);
#undef SILEX_SUBPROCESS_RESULT

extern "C" std::int64_t silexSystemErrorKindFromPosix(int code);
extern "C" std::int64_t silexSystemErrorKindFromWin32(std::uint32_t code);

namespace {

constexpr std::int64_t kInvalidInput = 3;
constexpr std::int64_t kInvalidData = 4;
constexpr std::int64_t kLimitExceeded = 7;

char* copyText(const std::string& text) {
    if (text.empty()) return nullptr;
    auto* result = static_cast<char*>(std::malloc(text.size()));
    if (result != nullptr) std::memcpy(result, text.data(), text.size());
    return result;
}

bool validUtf8(const std::string& text) {
    std::size_t offset = 0;
    while (offset < text.size()) {
        utf8proc_int32_t scalar = 0;
        const auto consumed = utf8proc_iterate(
            reinterpret_cast<const utf8proc_uint8_t*>(text.data() + offset),
            static_cast<utf8proc_ssize_t>(text.size() - offset), &scalar
        );
        if (consumed <= 0) return false;
        offset += static_cast<std::size_t>(consumed);
    }
    return true;
}

bool validText(const char* bytes, std::int64_t length, bool empty, std::string& output) {
    if (length < 0 || (!empty && length == 0) || (length > 0 && bytes == nullptr) ||
        (length > 0 && std::memchr(bytes, 0, static_cast<std::size_t>(length)) != nullptr)) return false;
    output.assign(bytes == nullptr ? "" : bytes, static_cast<std::size_t>(length));
    return validUtf8(output);
}

bool validName(const char* bytes, std::int64_t length, std::string& output) {
    return validText(bytes, length, false, output) && output.find('=') == std::string::npos;
}

template <typename Result, typename Tag>
void fail(Result* output, Tag tag, std::int64_t kind, const std::string& detail) {
    output->tag = tag;
    output->failure_value.kind = kind;
    output->failure_value.detail_bytes = copyText(detail);
    output->failure_value.detail_length = static_cast<std::int64_t>(detail.size());
}

#if defined(_WIN32)

std::int64_t errorKind(DWORD code) { return silexSystemErrorKindFromWin32(code); }
std::string errorDetail(DWORD code) { return std::system_category().message(static_cast<int>(code)); }

bool wide(const std::string& text, std::wstring& output) {
    if (text.empty()) { output.clear(); return true; }
    const auto needed = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text.data(),
        static_cast<int>(text.size()), nullptr, 0);
    if (needed <= 0) return false;
    output.resize(needed);
    return MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text.data(),
        static_cast<int>(text.size()), output.data(), needed) == needed;
}

std::wstring quote(const std::wstring& value) {
    if (value.find_first_of(L" \t\"") == std::wstring::npos && !value.empty()) return value;
    std::wstring result = L"\"";
    std::size_t slashes = 0;
    for (wchar_t c : value) {
        if (c == L'\\') { ++slashes; continue; }
        if (c == L'\"') { result.append(slashes * 2 + 1, L'\\'); result.push_back(c); slashes = 0; continue; }
        result.append(slashes, L'\\'); slashes = 0; result.push_back(c);
    }
    result.append(slashes * 2, L'\\');
    result.push_back(L'\"');
    return result;
}

bool equalName(const std::wstring& left, const std::wstring& right) {
    return CompareStringOrdinal(left.data(), static_cast<int>(left.size()),
        right.data(), static_cast<int>(right.size()), TRUE) == CSTR_EQUAL;
}

bool absolutePath(const std::wstring& value, std::wstring& output) {
    const auto needed = GetFullPathNameW(value.c_str(), 0, nullptr, nullptr);
    if (needed == 0) return false;
    output.resize(needed);
    const auto written = GetFullPathNameW(value.c_str(), needed, output.data(), nullptr);
    if (written == 0 || written >= needed) return false;
    output.resize(written);
    return true;
}

void closeHandle(HANDLE value) { if (value != nullptr && value != INVALID_HANDLE_VALUE) CloseHandle(value); }

bool runPlatform(
    SilexNative_STD_Subprocess_NativeCommand& command,
    SilexNative_STD_Subprocess_NativeOutput& output,
    std::int64_t& failureKind,
    std::string& failureDetail
) {
    std::wstring executable;
    std::wstring directory;
    if (!wide(command.executable, executable) ||
        (command.hasCurrentDirectory && !wide(command.currentDirectory, directory))) {
        failureKind = kInvalidInput; failureDetail = errorDetail(GetLastError()); return false;
    }
    std::wstring childDirectory;
    if (command.hasCurrentDirectory && !absolutePath(directory, childDirectory)) {
        failureKind = errorKind(GetLastError()); failureDetail = errorDetail(GetLastError()); return false;
    }
    std::wstring application = executable;
    const bool executableAbsolute = (executable.size() >= 2 && executable[1] == L':') ||
        (executable.size() >= 2 && executable[0] == L'\\' && executable[1] == L'\\');
    if (!executableAbsolute) {
        std::wstring combined;
        if (command.hasCurrentDirectory) combined = childDirectory + L"\\" + executable;
        else combined = executable;
        if (!absolutePath(combined, application)) {
            failureKind = errorKind(GetLastError()); failureDetail = errorDetail(GetLastError()); return false;
        }
    }
    std::wstring line = quote(executable);
    for (const auto& argument : command.arguments) {
        std::wstring value;
        if (!wide(argument, value)) { failureKind = kInvalidInput; failureDetail = errorDetail(GetLastError()); return false; }
        line += L" " + quote(value);
    }
    std::vector<std::pair<std::wstring, std::wstring>> environment;
    if (command.inheritEnvironment) {
        wchar_t* block = GetEnvironmentStringsW();
        if (block == nullptr) { failureKind = errorKind(GetLastError()); failureDetail = errorDetail(GetLastError()); return false; }
        for (const wchar_t* entry = block; *entry != L'\0'; entry += std::wcslen(entry) + 1) {
            std::wstring text(entry);
            const auto separator = text.find(L'=', text[0] == L'=' ? 1 : 0);
            if (separator != std::wstring::npos) environment.emplace_back(
                text.substr(0, separator), text.substr(separator + 1));
        }
        FreeEnvironmentStringsW(block);
    }
    auto removeEnvironment = [&](const std::wstring& name) {
        environment.erase(std::remove_if(environment.begin(), environment.end(),
            [&](const auto& entry) { return equalName(entry.first, name); }), environment.end());
    };
    for (const auto& nameText : command.environmentRemovals) {
        std::wstring name; if (!wide(nameText, name)) { failureKind = kInvalidInput; failureDetail = errorDetail(GetLastError()); return false; }
        removeEnvironment(name);
    }
    for (const auto& change : command.environmentSets) {
        std::wstring name, value;
        if (!wide(change.first, name) || !wide(change.second, value)) {
            failureKind = kInvalidInput; failureDetail = errorDetail(GetLastError()); return false;
        }
        removeEnvironment(name); environment.emplace_back(std::move(name), std::move(value));
    }
    std::sort(environment.begin(), environment.end(), [](const auto& left, const auto& right) {
        return CompareStringOrdinal(left.first.data(), static_cast<int>(left.first.size()),
            right.first.data(), static_cast<int>(right.first.size()), TRUE) == CSTR_LESS_THAN;
    });
    std::vector<wchar_t> environmentBlock;
    for (const auto& entry : environment) {
        environmentBlock.insert(environmentBlock.end(), entry.first.begin(), entry.first.end());
        environmentBlock.push_back(L'=');
        environmentBlock.insert(environmentBlock.end(), entry.second.begin(), entry.second.end());
        environmentBlock.push_back(L'\0');
    }
    environmentBlock.push_back(L'\0');
    if (environment.empty()) environmentBlock.push_back(L'\0');

    SECURITY_ATTRIBUTES security{sizeof(security), nullptr, TRUE};
    HANDLE inRead = nullptr, inWrite = nullptr, outRead = nullptr, outWrite = nullptr;
    HANDLE errRead = nullptr, errWrite = nullptr;
    if (!CreatePipe(&inRead, &inWrite, &security, 0) ||
        !CreatePipe(&outRead, &outWrite, &security, 0) ||
        !CreatePipe(&errRead, &errWrite, &security, 0)) {
        const auto code = GetLastError(); closeHandle(inRead); closeHandle(inWrite); closeHandle(outRead);
        closeHandle(outWrite); closeHandle(errRead); closeHandle(errWrite);
        failureKind = errorKind(code); failureDetail = errorDetail(code); return false;
    }
    SetHandleInformation(inWrite, HANDLE_FLAG_INHERIT, 0);
    SetHandleInformation(outRead, HANDLE_FLAG_INHERIT, 0);
    SetHandleInformation(errRead, HANDLE_FLAG_INHERIT, 0);
    STARTUPINFOW startup{}; startup.cb = sizeof(startup); startup.dwFlags = STARTF_USESTDHANDLES;
    startup.hStdInput = inRead; startup.hStdOutput = outWrite; startup.hStdError = errWrite;
    PROCESS_INFORMATION process{};
    std::vector<wchar_t> mutableLine(line.begin(), line.end()); mutableLine.push_back(L'\0');
    const BOOL created = CreateProcessW(application.c_str(), mutableLine.data(), nullptr, nullptr, TRUE,
        CREATE_UNICODE_ENVIRONMENT, environmentBlock.data(),
        command.hasCurrentDirectory ? childDirectory.c_str() : nullptr, &startup, &process);
    const auto createError = created ? ERROR_SUCCESS : GetLastError();
    closeHandle(inRead); closeHandle(outWrite); closeHandle(errWrite);
    if (!created) {
        closeHandle(inWrite); closeHandle(outRead); closeHandle(errRead);
        failureKind = errorKind(createError); failureDetail = errorDetail(createError); return false;
    }
    std::atomic<std::int64_t> total{0}; std::atomic<bool> limited{false};
    auto reader = [&](HANDLE handle, std::vector<std::uint8_t>& target) {
        std::uint8_t bytes[4096]; DWORD count = 0;
        while (ReadFile(handle, bytes, sizeof(bytes), &count, nullptr) && count > 0) {
            const auto previous = total.fetch_add(count);
            if (previous + count > command.maximumOutputBytes) {
                limited = true; TerminateProcess(process.hProcess, 1);
            } else target.insert(target.end(), bytes, bytes + count);
        }
        closeHandle(handle);
    };
    std::thread stdoutReader(reader, outRead, std::ref(output.standardOutput));
    std::thread stderrReader(reader, errRead, std::ref(output.standardError));
    std::thread inputWriter([&] {
        std::size_t offset = 0;
        while (offset < command.input.size()) {
            DWORD count = 0;
            if (!WriteFile(inWrite, command.input.data() + offset,
                    static_cast<DWORD>(std::min<std::size_t>(command.input.size() - offset, MAXDWORD)), &count, nullptr)) break;
            offset += count;
        }
        closeHandle(inWrite);
    });
    WaitForSingleObject(process.hProcess, INFINITE);
    inputWriter.join(); stdoutReader.join(); stderrReader.join();
    DWORD exitCode = 0; GetExitCodeProcess(process.hProcess, &exitCode);
    closeHandle(process.hThread); closeHandle(process.hProcess);
    if (limited) { failureKind = kLimitExceeded; failureDetail = "captured output exceeds maximum_output_bytes"; return false; }
    output.statusKind = 1; output.statusCode = exitCode; return true;
}

#else

std::int64_t errorKind(int code) { return silexSystemErrorKindFromPosix(code); }
std::string errorDetail(int code) { return std::system_category().message(code); }

bool runPlatform(
    SilexNative_STD_Subprocess_NativeCommand& command,
    SilexNative_STD_Subprocess_NativeOutput& output,
    std::int64_t& failureKind,
    std::string& failureDetail
) {
    std::vector<std::string> environment;
    if (command.inheritEnvironment) {
#if defined(__APPLE__)
        char** values = *_NSGetEnviron();
#else
        char** values = environ;
#endif
        for (; values != nullptr && *values != nullptr; ++values) environment.emplace_back(*values);
    }
    auto removeName = [&](const std::string& name) {
        environment.erase(std::remove_if(environment.begin(), environment.end(), [&](const std::string& entry) {
            return entry.size() > name.size() && entry.compare(0, name.size(), name) == 0 && entry[name.size()] == '=';
        }), environment.end());
    };
    for (const auto& name : command.environmentRemovals) removeName(name);
    for (const auto& change : command.environmentSets) { removeName(change.first); environment.push_back(change.first + "=" + change.second); }
    std::vector<char*> argv; argv.push_back(command.executable.data());
    for (auto& value : command.arguments) argv.push_back(value.data()); argv.push_back(nullptr);
    std::vector<char*> envp; for (auto& value : environment) envp.push_back(value.data()); envp.push_back(nullptr);
    int inputPipe[2], outputPipe[2], errorPipe[2], execPipe[2];
    if (pipe(inputPipe) || pipe(outputPipe) || pipe(errorPipe) || pipe(execPipe)) {
        const int code = errno; failureKind = errorKind(code); failureDetail = errorDetail(code); return false;
    }
    fcntl(execPipe[1], F_SETFD, FD_CLOEXEC);
    const pid_t child = fork();
    if (child < 0) { const int code = errno; failureKind = errorKind(code); failureDetail = errorDetail(code); return false; }
    if (child == 0) {
        close(inputPipe[1]); close(outputPipe[0]); close(errorPipe[0]); close(execPipe[0]);
        if (dup2(inputPipe[0], STDIN_FILENO) < 0 || dup2(outputPipe[1], STDOUT_FILENO) < 0 ||
            dup2(errorPipe[1], STDERR_FILENO) < 0 ||
            (command.hasCurrentDirectory && chdir(command.currentDirectory.c_str()) != 0)) {
            const int code = errno; (void)!write(execPipe[1], &code, sizeof(code)); _exit(127);
        }
        close(inputPipe[0]); close(outputPipe[1]); close(errorPipe[1]);
        execve(command.executable.c_str(), argv.data(), envp.data());
        const int code = errno; (void)!write(execPipe[1], &code, sizeof(code)); _exit(127);
    }
    close(inputPipe[0]); close(outputPipe[1]); close(errorPipe[1]); close(execPipe[1]);
    std::atomic<std::int64_t> total{0}; std::atomic<bool> limited{false};
    auto reader = [&](int descriptor, std::vector<std::uint8_t>& target) {
        std::uint8_t bytes[4096]; ssize_t count;
        while ((count = read(descriptor, bytes, sizeof(bytes))) > 0) {
            const auto previous = total.fetch_add(count);
            if (previous + count > command.maximumOutputBytes) { limited = true; kill(child, SIGKILL); }
            else target.insert(target.end(), bytes, bytes + count);
        }
        close(descriptor);
    };
    const auto oldSigpipe = signal(SIGPIPE, SIG_IGN);
    std::thread stdoutReader(reader, outputPipe[0], std::ref(output.standardOutput));
    std::thread stderrReader(reader, errorPipe[0], std::ref(output.standardError));
    std::thread inputWriter([&] {
        std::size_t offset = 0;
        while (offset < command.input.size()) {
            const auto count = write(inputPipe[1], command.input.data() + offset, command.input.size() - offset);
            if (count <= 0) break; offset += static_cast<std::size_t>(count);
        }
        close(inputPipe[1]);
    });
    int status = 0; while (waitpid(child, &status, 0) < 0 && errno == EINTR) {}
    inputWriter.join(); stdoutReader.join(); stderrReader.join(); signal(SIGPIPE, oldSigpipe);
    int execError = 0; const auto execCount = read(execPipe[0], &execError, sizeof(execError)); close(execPipe[0]);
    if (execCount == sizeof(execError)) { failureKind = errorKind(execError); failureDetail = errorDetail(execError); return false; }
    if (limited) { failureKind = kLimitExceeded; failureDetail = "captured output exceeds maximum_output_bytes"; return false; }
    if (WIFEXITED(status)) { output.statusKind = 1; output.statusCode = WEXITSTATUS(status); }
    else { output.statusKind = 2; output.statusCode = WTERMSIG(status); }
    return true;
}

#endif

} // namespace

extern "C" void silexNative_STD_Subprocess_discard_command(SilexNative_STD_Subprocess_NativeCommand* value) { delete value; }
extern "C" void silexNative_STD_Subprocess_discard_output(SilexNative_STD_Subprocess_NativeOutput* value) { delete value; }

extern "C" void silexNative_STD_Subprocess_native_create(
    const char* executableBytes, std::int64_t executableLength,
    bool hasCurrentDirectory, const char* directoryBytes, std::int64_t directoryLength,
    bool inheritEnvironment, std::int64_t maximumOutputBytes,
    SilexNative_STD_Subprocess_native_createResult* output
) {
    std::string executable, directory;
    if (maximumOutputBytes < 0 || !validText(executableBytes, executableLength, false, executable) ||
        (hasCurrentDirectory && !validText(directoryBytes, directoryLength, false, directory))) {
        fail(output, SilexNative_STD_Subprocess_native_createResultTag_failure, kInvalidInput, "invalid subprocess path or output limit"); return;
    }
    output->tag = SilexNative_STD_Subprocess_native_createResultTag_success;
    output->success_value = new SilexNative_STD_Subprocess_NativeCommand{
        std::move(executable), hasCurrentDirectory, std::move(directory), inheritEnvironment, maximumOutputBytes
    };
}

extern "C" void silexNative_STD_Subprocess_native_add_argument(
    SilexNative_STD_Subprocess_NativeCommand* command, const char* bytes, std::int64_t length,
    SilexNative_STD_Subprocess_native_add_argumentResult* output
) {
    std::string value;
    if (!validText(bytes, length, true, value)) { fail(output, SilexNative_STD_Subprocess_native_add_argumentResultTag_failure, kInvalidInput, "invalid subprocess argument"); return; }
    command->arguments.push_back(std::move(value)); output->tag = SilexNative_STD_Subprocess_native_add_argumentResultTag_success;
}

extern "C" void silexNative_STD_Subprocess_native_set_environment(
    SilexNative_STD_Subprocess_NativeCommand* command, const char* nameBytes, std::int64_t nameLength,
    const char* valueBytes, std::int64_t valueLength, SilexNative_STD_Subprocess_native_set_environmentResult* output
) {
    std::string name, value;
    if (!validName(nameBytes, nameLength, name) || !validText(valueBytes, valueLength, true, value)) {
        fail(output, SilexNative_STD_Subprocess_native_set_environmentResultTag_failure, kInvalidInput, "invalid subprocess environment change"); return;
    }
    command->environmentSets.emplace_back(std::move(name), std::move(value)); output->tag = SilexNative_STD_Subprocess_native_set_environmentResultTag_success;
}

extern "C" void silexNative_STD_Subprocess_native_remove_environment(
    SilexNative_STD_Subprocess_NativeCommand* command, const char* bytes, std::int64_t length,
    SilexNative_STD_Subprocess_native_remove_environmentResult* output
) {
    std::string name;
    if (!validName(bytes, length, name)) { fail(output, SilexNative_STD_Subprocess_native_remove_environmentResultTag_failure, kInvalidInput, "invalid subprocess environment name"); return; }
    command->environmentRemovals.push_back(std::move(name)); output->tag = SilexNative_STD_Subprocess_native_remove_environmentResultTag_success;
}

extern "C" void silexNative_STD_Subprocess_native_set_input(
    SilexNative_STD_Subprocess_NativeCommand* command, const std::uint8_t* bytes, std::int64_t length,
    SilexNative_STD_Subprocess_native_set_inputResult* output
) {
    command->input.assign(bytes, bytes + length); output->tag = SilexNative_STD_Subprocess_native_set_inputResultTag_success;
}

extern "C" void silexNative_STD_Subprocess_native_run(
    SilexNative_STD_Subprocess_NativeCommand* command,
    SilexNative_STD_Subprocess_native_runResult* result
) {
    auto* output = new SilexNative_STD_Subprocess_NativeOutput;
    std::int64_t kind = 0; std::string detail;
    const bool succeeded = runPlatform(*command, *output, kind, detail); delete command;
    if (!succeeded) { delete output; fail(result, SilexNative_STD_Subprocess_native_runResultTag_failure, kind, detail); return; }
    result->tag = SilexNative_STD_Subprocess_native_runResultTag_success; result->success_value = output;
}

extern "C" std::int64_t silexNative_STD_Subprocess_native_status_kind(SilexNative_STD_Subprocess_NativeOutput* output) { return output->statusKind; }
extern "C" std::int64_t silexNative_STD_Subprocess_native_status_code(SilexNative_STD_Subprocess_NativeOutput* output) { return output->statusCode; }
extern "C" void silexNative_STD_Subprocess_native_visit_bytes(
    SilexNative_STD_Subprocess_NativeOutput* output, std::int64_t stream,
    void (*visitor)(void*, std::int64_t), void* context
) {
    const auto& bytes = stream == 1 ? output->standardOutput : output->standardError;
    for (const auto byte : bytes) visitor(context, byte);
}
