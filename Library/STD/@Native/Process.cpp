#include <algorithm>
#include <cerrno>
#include <cstdint>
#include <cwchar>
#include <cstdlib>
#include <cstring>
#include <limits>
#include <string>
#include <system_error>
#include <vector>

#include "Unicode/utf8proc/utf8proc.h"

#if defined(_WIN32)
#include <windows.h>
#include <shellapi.h>
#else
#include <unistd.h>
#if defined(__APPLE__)
#include <mach-o/dyld.h>
#endif
#endif

struct SilexProcessOperationResult {
    bool succeeded;
    std::int64_t errorKind;
    char* detailBytes;
    std::int64_t detailLength;
};

struct SilexProcessPathResult {
    bool succeeded;
    std::int64_t errorKind;
    char* pathBytes;
    std::int64_t pathLength;
    char* detailBytes;
    std::int64_t detailLength;
};

extern "C" std::int64_t silexSystemErrorKindFromPosix(int code);
extern "C" std::int64_t silexSystemErrorKindFromWin32(std::uint32_t code);
extern "C" std::int64_t silexRuntimeArgumentCount();
extern "C" const char* silexRuntimeArgumentValue(std::int64_t index, std::int64_t* length);

namespace {

constexpr std::int64_t kInvalidInput = 3;
constexpr std::int64_t kInvalidData = 4;
constexpr std::int64_t kUnsupported = 29;

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
            static_cast<utf8proc_ssize_t>(text.size() - offset),
            &scalar
        );
        if (consumed <= 0) return false;
        offset += static_cast<std::size_t>(consumed);
    }
    return true;
}

void succeed(SilexProcessOperationResult* output) {
    output->succeeded = true;
    output->errorKind = 0;
    output->detailBytes = nullptr;
    output->detailLength = 0;
}

void fail(
    SilexProcessOperationResult* output,
    std::int64_t kind,
    const std::string& detail
) {
    output->succeeded = false;
    output->errorKind = kind;
    output->detailBytes = copyText(detail);
    output->detailLength = static_cast<std::int64_t>(detail.size());
}

void fail(
    SilexProcessPathResult* output,
    std::int64_t kind,
    const std::string& detail
) {
    output->succeeded = false;
    output->errorKind = kind;
    output->pathBytes = nullptr;
    output->pathLength = 0;
    output->detailBytes = copyText(detail);
    output->detailLength = static_cast<std::int64_t>(detail.size());
}

void pathSuccess(SilexProcessPathResult* output, const std::string& path) {
    output->succeeded = true;
    output->errorKind = 0;
    output->pathBytes = copyText(path);
    output->pathLength = static_cast<std::int64_t>(path.size());
    output->detailBytes = nullptr;
    output->detailLength = 0;
}

#if defined(_WIN32)

std::int64_t lastErrorKind() {
    return silexSystemErrorKindFromWin32(GetLastError());
}

std::string lastErrorDetail() {
    return std::system_category().message(static_cast<int>(GetLastError()));
}

bool wideText(const char* bytes, std::int64_t length, std::wstring& output) {
    if (bytes == nullptr || length <= 0 ||
        std::memchr(bytes, 0, static_cast<std::size_t>(length)) != nullptr ||
        length > std::numeric_limits<int>::max()) {
        SetLastError(ERROR_INVALID_NAME);
        return false;
    }
    const auto required = MultiByteToWideChar(
        CP_UTF8, MB_ERR_INVALID_CHARS, bytes, static_cast<int>(length), nullptr, 0
    );
    if (required <= 0) return false;
    output.resize(static_cast<std::size_t>(required));
    return MultiByteToWideChar(
        CP_UTF8, MB_ERR_INVALID_CHARS, bytes, static_cast<int>(length),
        output.data(), required
    ) == required;
}

bool utf8Text(const wchar_t* text, std::size_t length, std::string& output) {
    if (length > static_cast<std::size_t>(std::numeric_limits<int>::max())) {
        SetLastError(ERROR_FILENAME_EXCED_RANGE);
        return false;
    }
    if (length == 0) {
        output.clear();
        return true;
    }
    const auto required = WideCharToMultiByte(
        CP_UTF8, WC_ERR_INVALID_CHARS, text, static_cast<int>(length),
        nullptr, 0, nullptr, nullptr
    );
    if (required <= 0) return false;
    output.resize(static_cast<std::size_t>(required));
    if (WideCharToMultiByte(
            CP_UTF8, WC_ERR_INVALID_CHARS, text, static_cast<int>(length),
            output.data(), required, nullptr, nullptr
        ) != required) return false;
    std::replace(output.begin(), output.end(), '\\', '/');
    return true;
}

#else

std::int64_t lastErrorKind() {
    return silexSystemErrorKindFromPosix(errno);
}

std::string lastErrorDetail() {
    return std::system_category().message(errno);
}

bool posixPath(const char* bytes, std::int64_t length, std::string& output) {
    if (bytes == nullptr || length <= 0 ||
        std::memchr(bytes, 0, static_cast<std::size_t>(length)) != nullptr) {
        errno = EINVAL;
        return false;
    }
    output.assign(bytes, static_cast<std::size_t>(length));
    return validUtf8(output);
}

#endif

} // namespace

extern "C" void silexNative_STD_Process_native_visit_arguments(
    void (*visitor)(void*, std::int64_t, std::int64_t),
    void* visitorContext,
    SilexProcessOperationResult* output
) {
#if defined(_WIN32)
    int count = 0;
    wchar_t** values = CommandLineToArgvW(GetCommandLineW(), &count);
    if (values == nullptr) {
        fail(output, lastErrorKind(), lastErrorDetail());
        return;
    }
    std::vector<std::string> arguments;
    for (int index = 0; index < count; ++index) {
        std::string value;
        if (!utf8Text(values[index], std::wcslen(values[index]), value)) {
            LocalFree(values);
            fail(output, kInvalidData, lastErrorDetail());
            return;
        }
        arguments.push_back(std::move(value));
    }
    LocalFree(values);
#else
    std::vector<std::string> arguments;
    const auto count = silexRuntimeArgumentCount();
    for (std::int64_t index = 0; index < count; ++index) {
        std::int64_t length = 0;
        const char* bytes = silexRuntimeArgumentValue(index, &length);
        std::string value(bytes == nullptr ? "" : bytes, static_cast<std::size_t>(length));
        if (!validUtf8(value)) {
            fail(output, kInvalidData, "process argument is not valid UTF-8");
            return;
        }
        arguments.push_back(std::move(value));
    }
#endif
    for (const auto& argument : arguments) {
        visitor(visitorContext, 1, static_cast<std::int64_t>(argument.size()));
        for (const unsigned char byte : argument) visitor(visitorContext, 0, byte);
    }
    succeed(output);
}

extern "C" void silexNative_STD_Process_native_current_directory(
    SilexProcessPathResult* output
) {
#if defined(_WIN32)
    const auto required = GetCurrentDirectoryW(0, nullptr);
    if (required == 0) {
        fail(output, lastErrorKind(), lastErrorDetail());
        return;
    }
    std::wstring wide(required, L'\0');
    const auto written = GetCurrentDirectoryW(required, wide.data());
    if (written + 1 != required) {
        fail(output, lastErrorKind(), lastErrorDetail());
        return;
    }
    wide.resize(written);
    std::string path;
    if (!utf8Text(wide.data(), wide.size(), path)) {
        fail(output, kInvalidData, lastErrorDetail());
        return;
    }
#else
    std::vector<char> buffer(256);
    while (::getcwd(buffer.data(), buffer.size()) == nullptr) {
        if (errno != ERANGE) {
            fail(output, lastErrorKind(), lastErrorDetail());
            return;
        }
        buffer.resize(buffer.size() * 2);
    }
    const std::string path(buffer.data());
    if (!validUtf8(path)) {
        fail(output, kInvalidData, "current directory is not valid UTF-8");
        return;
    }
#endif
    pathSuccess(output, path);
}

extern "C" void silexNative_STD_Process_native_set_current_directory(
    const char* pathBytes,
    std::int64_t pathLength,
    SilexProcessOperationResult* output
) {
#if defined(_WIN32)
    std::wstring path;
    if (!wideText(pathBytes, pathLength, path)) {
        fail(output, kInvalidInput, lastErrorDetail());
        return;
    }
    if (!SetCurrentDirectoryW(path.c_str())) {
        fail(output, lastErrorKind(), lastErrorDetail());
        return;
    }
#else
    std::string path;
    if (!posixPath(pathBytes, pathLength, path)) {
        fail(output, kInvalidInput, "current directory path is invalid");
        return;
    }
    if (::chdir(path.c_str()) != 0) {
        fail(output, lastErrorKind(), lastErrorDetail());
        return;
    }
#endif
    succeed(output);
}

extern "C" void silexNative_STD_Process_native_executable_path(
    SilexProcessPathResult* output
) {
#if defined(SILEX_PROCESS_SIMULATE_EXECUTABLE_UNAVAILABLE)
    fail(output, kUnsupported, "executable path is unavailable");
#elif defined(_WIN32)
    std::vector<wchar_t> buffer(260);
    while (true) {
        SetLastError(ERROR_SUCCESS);
        const auto written = GetModuleFileNameW(nullptr, buffer.data(), static_cast<DWORD>(buffer.size()));
        if (written == 0) {
            fail(output, lastErrorKind(), lastErrorDetail());
            return;
        }
        if (written < buffer.size() - 1) {
            std::string path;
            if (!utf8Text(buffer.data(), written, path)) {
                fail(output, kInvalidData, lastErrorDetail());
                return;
            }
            pathSuccess(output, path);
            return;
        }
        buffer.resize(buffer.size() * 2);
    }
#elif defined(__APPLE__)
    std::uint32_t size = 0;
    if (_NSGetExecutablePath(nullptr, &size) != -1 || size == 0) {
        fail(output, kUnsupported, "executable path is unavailable");
        return;
    }
    std::vector<char> unresolved(size);
    if (_NSGetExecutablePath(unresolved.data(), &size) != 0) {
        fail(output, kUnsupported, "executable path is unavailable");
        return;
    }
    char* resolved = ::realpath(unresolved.data(), nullptr);
    if (resolved == nullptr) {
        fail(output, lastErrorKind(), lastErrorDetail());
        return;
    }
    const std::string path(resolved);
    std::free(resolved);
    if (!validUtf8(path)) {
        fail(output, kInvalidData, "executable path is not valid UTF-8");
        return;
    }
    pathSuccess(output, path);
#elif defined(__linux__)
    std::vector<char> buffer(256);
    while (true) {
        const auto written = ::readlink("/proc/self/exe", buffer.data(), buffer.size());
        if (written < 0) {
            fail(output, lastErrorKind(), lastErrorDetail());
            return;
        }
        if (static_cast<std::size_t>(written) < buffer.size()) {
            const std::string path(buffer.data(), static_cast<std::size_t>(written));
            if (!validUtf8(path)) {
                fail(output, kInvalidData, "executable path is not valid UTF-8");
                return;
            }
            pathSuccess(output, path);
            return;
        }
        buffer.resize(buffer.size() * 2);
    }
#else
    fail(output, kUnsupported, "executable path is unavailable on this platform");
#endif
}

extern "C" std::uint64_t silexNative_STD_Process_native_id() {
#if defined(_WIN32)
    return static_cast<std::uint64_t>(GetCurrentProcessId());
#else
    return static_cast<std::uint64_t>(::getpid());
#endif
}
