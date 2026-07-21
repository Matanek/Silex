#include <algorithm>
#include <cerrno>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <limits>
#include <string>
#include <system_error>
#include <unordered_set>
#include <utility>
#include <vector>

#include "Unicode/utf8proc/utf8proc.h"

#if defined(_WIN32)
#include <windows.h>
#else
#if defined(__APPLE__)
#include <crt_externs.h>
#else
extern char** environ;
#endif
#endif

struct SilexEnvironmentLookupResult {
    bool succeeded;
    std::int64_t errorKind;
    bool present;
    char* valueBytes;
    std::int64_t valueLength;
    char* detailBytes;
    std::int64_t detailLength;
};

struct SilexEnvironmentOperationResult {
    bool succeeded;
    std::int64_t errorKind;
    char* detailBytes;
    std::int64_t detailLength;
};

extern "C" std::int64_t silexSystemErrorKindFromPosix(int code);
extern "C" std::int64_t silexSystemErrorKindFromWin32(std::uint32_t code);

namespace {

constexpr std::int64_t kInvalidInput = 3;
constexpr std::int64_t kInvalidData = 4;

struct Variable {
    std::string name;
    std::string value;
};

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

bool validName(const char* bytes, std::int64_t length, std::string& output) {
    if (bytes == nullptr || length <= 0 ||
        std::memchr(bytes, 0, static_cast<std::size_t>(length)) != nullptr ||
        std::memchr(bytes, '=', static_cast<std::size_t>(length)) != nullptr) return false;
    output.assign(bytes, static_cast<std::size_t>(length));
    return validUtf8(output);
}

bool validValue(const char* bytes, std::int64_t length, std::string& output) {
    if (length < 0 || (length > 0 && bytes == nullptr) ||
        (length > 0 && std::memchr(bytes, 0, static_cast<std::size_t>(length)) != nullptr)) return false;
    output.assign(bytes == nullptr ? "" : bytes, static_cast<std::size_t>(length));
    return validUtf8(output);
}

void succeed(SilexEnvironmentOperationResult* output) {
    output->succeeded = true;
    output->errorKind = 0;
    output->detailBytes = nullptr;
    output->detailLength = 0;
}

void fail(
    SilexEnvironmentOperationResult* output,
    std::int64_t kind,
    const std::string& detail
) {
    output->succeeded = false;
    output->errorKind = kind;
    output->detailBytes = copyText(detail);
    output->detailLength = static_cast<std::int64_t>(detail.size());
}

bool byteLess(const Variable& left, const Variable& right) {
    return std::lexicographical_compare(
        left.name.begin(), left.name.end(), right.name.begin(), right.name.end(),
        [](char a, char b) {
            return static_cast<unsigned char>(a) < static_cast<unsigned char>(b);
        }
    );
}

#if defined(_WIN32)

bool wideText(const std::string& text, std::wstring& output) {
    if (text.size() > static_cast<std::size_t>(std::numeric_limits<int>::max())) {
        SetLastError(ERROR_FILENAME_EXCED_RANGE);
        return false;
    }
    if (text.empty()) {
        output.clear();
        return true;
    }
    const auto required = MultiByteToWideChar(
        CP_UTF8, MB_ERR_INVALID_CHARS, text.data(), static_cast<int>(text.size()), nullptr, 0
    );
    if (required <= 0) return false;
    output.resize(static_cast<std::size_t>(required));
    return MultiByteToWideChar(
        CP_UTF8, MB_ERR_INVALID_CHARS, text.data(), static_cast<int>(text.size()),
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
    return WideCharToMultiByte(
        CP_UTF8, WC_ERR_INVALID_CHARS, text, static_cast<int>(length),
        output.data(), required, nullptr, nullptr
    ) == required;
}

std::int64_t lastErrorKind() {
    return silexSystemErrorKindFromWin32(GetLastError());
}

std::string lastErrorDetail() {
    return std::system_category().message(static_cast<int>(GetLastError()));
}

#else

std::int64_t lastErrorKind() {
    return silexSystemErrorKindFromPosix(errno);
}

std::string lastErrorDetail() {
    return std::system_category().message(errno);
}

#endif

} // namespace

extern "C" void silexNative_STD_Environment_native_get(
    const char* nameBytes,
    std::int64_t nameLength,
    SilexEnvironmentLookupResult* output
) {
    std::string name;
    if (!validName(nameBytes, nameLength, name)) {
        output->succeeded = false;
        output->errorKind = kInvalidInput;
        const std::string detail = "environment variable name is invalid";
        output->detailBytes = copyText(detail);
        output->detailLength = static_cast<std::int64_t>(detail.size());
        return;
    }
#if defined(_WIN32)
    std::wstring wideName;
    if (!wideText(name, wideName)) {
        output->succeeded = false;
        output->errorKind = kInvalidInput;
        const auto detail = lastErrorDetail();
        output->detailBytes = copyText(detail);
        output->detailLength = static_cast<std::int64_t>(detail.size());
        return;
    }
    SetLastError(ERROR_SUCCESS);
    const auto required = GetEnvironmentVariableW(wideName.c_str(), nullptr, 0);
    if (required == 0 && GetLastError() == ERROR_ENVVAR_NOT_FOUND) {
        output->succeeded = true;
        output->errorKind = 0;
        output->present = false;
        output->valueBytes = nullptr;
        output->valueLength = 0;
        output->detailBytes = nullptr;
        output->detailLength = 0;
        return;
    }
    std::wstring wideValue;
    if (required > 0) {
        wideValue.resize(required);
        const auto written = GetEnvironmentVariableW(wideName.c_str(), wideValue.data(), required);
        if (written + 1 != required) {
            output->succeeded = false;
            output->errorKind = lastErrorKind();
            const auto detail = lastErrorDetail();
            output->detailBytes = copyText(detail);
            output->detailLength = static_cast<std::int64_t>(detail.size());
            return;
        }
        wideValue.resize(written);
    }
    std::string value;
    if (!utf8Text(wideValue.data(), wideValue.size(), value)) {
        output->succeeded = false;
        output->errorKind = kInvalidData;
        const auto detail = lastErrorDetail();
        output->detailBytes = copyText(detail);
        output->detailLength = static_cast<std::int64_t>(detail.size());
        return;
    }
#else
    const char* found = std::getenv(name.c_str());
    if (found == nullptr) {
        output->succeeded = true;
        output->errorKind = 0;
        output->present = false;
        output->valueBytes = nullptr;
        output->valueLength = 0;
        output->detailBytes = nullptr;
        output->detailLength = 0;
        return;
    }
    const std::string value(found);
    if (!validUtf8(value)) {
        output->succeeded = false;
        output->errorKind = kInvalidData;
        const std::string detail = "environment variable value is not valid UTF-8";
        output->detailBytes = copyText(detail);
        output->detailLength = static_cast<std::int64_t>(detail.size());
        return;
    }
#endif
    output->succeeded = true;
    output->errorKind = 0;
    output->present = true;
    output->valueBytes = copyText(value);
    output->valueLength = static_cast<std::int64_t>(value.size());
    output->detailBytes = nullptr;
    output->detailLength = 0;
}

extern "C" void silexNative_STD_Environment_native_set(
    const char* nameBytes,
    std::int64_t nameLength,
    const char* valueBytes,
    std::int64_t valueLength,
    SilexEnvironmentOperationResult* output
) {
    std::string name;
    std::string value;
    if (!validName(nameBytes, nameLength, name) || !validValue(valueBytes, valueLength, value)) {
        fail(output, kInvalidInput, "environment variable name or value is invalid");
        return;
    }
#if defined(_WIN32)
    std::wstring wideName;
    std::wstring wideValue;
    if (!wideText(name, wideName) || !wideText(value, wideValue) ||
        !SetEnvironmentVariableW(wideName.c_str(), wideValue.c_str())) {
        fail(output, lastErrorKind(), lastErrorDetail());
        return;
    }
#else
    if (::setenv(name.c_str(), value.c_str(), 1) != 0) {
        fail(output, lastErrorKind(), lastErrorDetail());
        return;
    }
#endif
    succeed(output);
}

extern "C" void silexNative_STD_Environment_native_remove(
    const char* nameBytes,
    std::int64_t nameLength,
    SilexEnvironmentOperationResult* output
) {
    std::string name;
    if (!validName(nameBytes, nameLength, name)) {
        fail(output, kInvalidInput, "environment variable name is invalid");
        return;
    }
#if defined(_WIN32)
    std::wstring wideName;
    if (!wideText(name, wideName)) {
        fail(output, kInvalidInput, lastErrorDetail());
        return;
    }
    if (!SetEnvironmentVariableW(wideName.c_str(), nullptr) &&
        GetLastError() != ERROR_ENVVAR_NOT_FOUND) {
        fail(output, lastErrorKind(), lastErrorDetail());
        return;
    }
#else
    if (::unsetenv(name.c_str()) != 0) {
        fail(output, lastErrorKind(), lastErrorDetail());
        return;
    }
#endif
    succeed(output);
}

extern "C" void silexNative_STD_Environment_native_visit_variables(
    void (*visitor)(void*, std::int64_t, std::int64_t),
    void* visitorContext,
    SilexEnvironmentOperationResult* output
) {
    std::vector<Variable> variables;
#if defined(_WIN32)
    wchar_t* block = GetEnvironmentStringsW();
    if (block == nullptr) {
        fail(output, lastErrorKind(), lastErrorDetail());
        return;
    }
    std::vector<std::wstring> names;
    for (const wchar_t* entry = block; *entry != L'\0'; entry += std::wcslen(entry) + 1) {
        const std::wstring text(entry);
        if (!text.empty() && text[0] == L'=') continue;
        const auto separator = text.find(L'=');
        if (separator == std::wstring::npos || separator == 0) {
            FreeEnvironmentStringsW(block);
            fail(output, kInvalidData, "native environment entry is malformed");
            return;
        }
        const auto name = text.substr(0, separator);
        bool duplicate = false;
        for (const auto& existing : names) {
            if (CompareStringOrdinal(
                    existing.data(), static_cast<int>(existing.size()),
                    name.data(), static_cast<int>(name.size()), TRUE
                ) == CSTR_EQUAL) {
                duplicate = true;
                break;
            }
        }
        if (!duplicate) names.push_back(name);
    }
    FreeEnvironmentStringsW(block);
    for (const auto& wideName : names) {
        std::string name;
        if (!utf8Text(wideName.data(), wideName.size(), name)) {
            fail(output, kInvalidData, lastErrorDetail());
            return;
        }
        SetLastError(ERROR_SUCCESS);
        const auto required = GetEnvironmentVariableW(wideName.c_str(), nullptr, 0);
        if (required == 0 && GetLastError() == ERROR_ENVVAR_NOT_FOUND) continue;
        std::wstring wideValue;
        if (required > 0) {
            wideValue.resize(required);
            const auto written = GetEnvironmentVariableW(wideName.c_str(), wideValue.data(), required);
            if (written + 1 != required) {
                fail(output, lastErrorKind(), lastErrorDetail());
                return;
            }
            wideValue.resize(written);
        }
        std::string value;
        if (!utf8Text(wideValue.data(), wideValue.size(), value)) {
            fail(output, kInvalidData, lastErrorDetail());
            return;
        }
        variables.push_back(Variable{std::move(name), std::move(value)});
    }
#else
#if defined(__APPLE__)
    char** environment = *_NSGetEnviron();
#else
    char** environment = environ;
#endif
    std::unordered_set<std::string> names;
    for (char** current = environment; current != nullptr && *current != nullptr; ++current) {
        const std::string text(*current);
        const auto separator = text.find('=');
        if (separator == std::string::npos || separator == 0 || !validUtf8(text)) {
            fail(output, kInvalidData, "native environment entry is not valid UTF-8");
            return;
        }
        names.insert(text.substr(0, separator));
    }
    for (const auto& name : names) {
        const char* found = std::getenv(name.c_str());
        if (found == nullptr) continue;
        std::string value(found);
        if (!validUtf8(value)) {
            fail(output, kInvalidData, "native environment value is not valid UTF-8");
            return;
        }
        variables.push_back(Variable{name, std::move(value)});
    }
#endif
    std::sort(variables.begin(), variables.end(), byteLess);
    for (const auto& variable : variables) {
        visitor(visitorContext, 1, static_cast<std::int64_t>(variable.name.size()));
        for (const unsigned char byte : variable.name) visitor(visitorContext, 0, byte);
        visitor(visitorContext, 2, static_cast<std::int64_t>(variable.value.size()));
        for (const unsigned char byte : variable.value) visitor(visitorContext, 0, byte);
    }
    succeed(output);
}
