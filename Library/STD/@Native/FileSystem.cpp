#include <algorithm>
#include <cerrno>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <limits>
#include <string>
#include <system_error>
#include <utility>
#include <vector>

#include "Unicode/utf8proc/utf8proc.h"

#if defined(_WIN32)
#include <windows.h>
#endif

struct SilexFileSystemOperationResult {
    bool succeeded;
    std::int64_t errorKind;
    char* detailBytes;
    std::int64_t detailLength;
};

struct SilexFileSystemMetadataResult {
    bool succeeded;
    std::int64_t errorKind;
    std::int64_t fileKind;
    std::int64_t size;
    bool readonly;
    char* detailBytes;
    std::int64_t detailLength;
};

struct SilexFileSystemPathResult {
    bool succeeded;
    std::int64_t errorKind;
    char* pathBytes;
    std::int64_t pathLength;
    char* detailBytes;
    std::int64_t detailLength;
};

extern "C" std::int64_t silexSystemErrorKindFromPosix(int code);
extern "C" std::int64_t silexSystemErrorKindFromWin32(std::uint32_t code);

namespace {

namespace fs = std::filesystem;

constexpr std::int64_t kNotFound = 0;
constexpr std::int64_t kAlreadyExists = 1;
constexpr std::int64_t kInvalidData = 4;
constexpr std::int64_t kLimitExceeded = 7;
constexpr std::int64_t kNotDirectory = 8;
constexpr std::int64_t kIsDirectory = 9;

char* copyText(const std::string& text) {
    if (text.empty()) return nullptr;
    auto* result = static_cast<char*>(std::malloc(text.size()));
    if (result != nullptr) std::memcpy(result, text.data(), text.size());
    return result;
}

std::int64_t errorKind(const std::error_code& error) {
#if defined(_WIN32)
    return silexSystemErrorKindFromWin32(static_cast<std::uint32_t>(error.value()));
#else
    return silexSystemErrorKindFromPosix(error.value());
#endif
}

std::int64_t nativeErrorKind() {
#if defined(_WIN32)
    return silexSystemErrorKindFromWin32(GetLastError());
#else
    return silexSystemErrorKindFromPosix(errno);
#endif
}

std::string nativeErrorDetail() {
#if defined(_WIN32)
    return std::system_category().message(static_cast<int>(GetLastError()));
#else
    return std::system_category().message(errno);
#endif
}

void succeed(SilexFileSystemOperationResult* output) {
    output->succeeded = true;
    output->errorKind = 0;
    output->detailBytes = nullptr;
    output->detailLength = 0;
}

void fail(
    SilexFileSystemOperationResult* output,
    std::int64_t kind,
    const std::string& detail
) {
    output->succeeded = false;
    output->errorKind = kind;
    output->detailBytes = copyText(detail);
    output->detailLength = static_cast<std::int64_t>(detail.size());
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

bool nativePath(const char* bytes, std::int64_t length, fs::path& output) {
    if (length <= 0 || bytes == nullptr ||
        std::memchr(bytes, 0, static_cast<std::size_t>(length)) != nullptr) {
#if defined(_WIN32)
        SetLastError(ERROR_INVALID_NAME);
#else
        errno = EINVAL;
#endif
        return false;
    }
#if defined(_WIN32)
    if (length > std::numeric_limits<int>::max()) {
        SetLastError(ERROR_FILENAME_EXCED_RANGE);
        return false;
    }
    const auto required = MultiByteToWideChar(
        CP_UTF8, MB_ERR_INVALID_CHARS, bytes, static_cast<int>(length), nullptr, 0
    );
    if (required <= 0) return false;
    std::wstring wide(static_cast<std::size_t>(required), L'\0');
    if (MultiByteToWideChar(
            CP_UTF8, MB_ERR_INVALID_CHARS, bytes, static_cast<int>(length),
            wide.data(), required
        ) != required) return false;
    output = fs::path(std::move(wide));
#else
    std::string text(bytes, static_cast<std::size_t>(length));
    if (!validUtf8(text)) {
        errno = EILSEQ;
        return false;
    }
    output = fs::path(std::move(text));
#endif
    return true;
}

bool utf8Path(const fs::path& path, std::string& output) {
#if defined(_WIN32)
    const auto& wide = path.native();
    if (wide.empty()) {
        output.clear();
        return true;
    }
    if (wide.size() > static_cast<std::size_t>(std::numeric_limits<int>::max())) {
        SetLastError(ERROR_FILENAME_EXCED_RANGE);
        return false;
    }
    const auto required = WideCharToMultiByte(
        CP_UTF8, WC_ERR_INVALID_CHARS, wide.data(), static_cast<int>(wide.size()),
        nullptr, 0, nullptr, nullptr
    );
    if (required <= 0) return false;
    output.resize(static_cast<std::size_t>(required));
    if (WideCharToMultiByte(
            CP_UTF8, WC_ERR_INVALID_CHARS, wide.data(), static_cast<int>(wide.size()),
            output.data(), required, nullptr, nullptr
        ) != required) return false;
    std::replace(output.begin(), output.end(), '\\', '/');
#else
    output = path.native();
    if (!validUtf8(output)) {
        errno = EILSEQ;
        return false;
    }
#endif
    return true;
}

std::int64_t fileKind(fs::file_type type) {
    if (type == fs::file_type::regular) return 1;
    if (type == fs::file_type::directory) return 2;
    if (type == fs::file_type::symlink) return 3;
    return 4;
}

bool isReadonly(const fs::path& path, bool follow, const fs::file_status& status) {
#if defined(_WIN32)
    fs::path inspected = path;
    if (follow) {
        std::error_code error;
        inspected = fs::canonical(path, error);
        if (error) return false;
    }
    const auto attributes = GetFileAttributesW(inspected.c_str());
    return attributes != INVALID_FILE_ATTRIBUTES &&
        (attributes & FILE_ATTRIBUTE_READONLY) != 0;
#else
    (void)path;
    (void)follow;
    const auto writable = fs::perms::owner_write | fs::perms::group_write |
        fs::perms::others_write;
    return (status.permissions() & writable) == fs::perms::none;
#endif
}

bool byteLess(const std::string& left, const std::string& right) {
    return std::lexicographical_compare(
        left.begin(), left.end(), right.begin(), right.end(),
        [](char a, char b) {
            return static_cast<unsigned char>(a) < static_cast<unsigned char>(b);
        }
    );
}

bool pathExists(const fs::path& path, fs::file_status& status, std::error_code& error) {
    status = fs::symlink_status(path, error);
    if (error) {
        if (errorKind(error) == kNotFound) {
            error.clear();
            return false;
        }
        return false;
    }
    return status.type() != fs::file_type::not_found;
}

} // namespace

extern "C" void silexNative_STD_FileSystem_native_metadata(
    const char* pathBytes,
    std::int64_t pathLength,
    bool follow,
    SilexFileSystemMetadataResult* output
) {
    fs::path path;
    if (!nativePath(pathBytes, pathLength, path)) {
        output->succeeded = false;
        output->errorKind = nativeErrorKind();
        const auto detail = nativeErrorDetail();
        output->detailBytes = copyText(detail);
        output->detailLength = static_cast<std::int64_t>(detail.size());
        return;
    }
    std::error_code error;
    const auto status = follow ? fs::status(path, error) : fs::symlink_status(path, error);
    if (error) {
        output->succeeded = false;
        output->errorKind = errorKind(error);
        const auto detail = error.message();
        output->detailBytes = copyText(detail);
        output->detailLength = static_cast<std::int64_t>(detail.size());
        return;
    }
    if (status.type() == fs::file_type::not_found) {
        output->succeeded = false;
        output->errorKind = kNotFound;
        const std::string detail = "path does not exist";
        output->detailBytes = copyText(detail);
        output->detailLength = static_cast<std::int64_t>(detail.size());
        return;
    }
    std::uintmax_t size = 0;
    if (status.type() == fs::file_type::regular) {
        size = fs::file_size(path, error);
        if (error) {
            output->succeeded = false;
            output->errorKind = errorKind(error);
            const auto detail = error.message();
            output->detailBytes = copyText(detail);
            output->detailLength = static_cast<std::int64_t>(detail.size());
            return;
        }
        if (size > static_cast<std::uintmax_t>(std::numeric_limits<std::int64_t>::max())) {
            output->succeeded = false;
            output->errorKind = kLimitExceeded;
            const std::string detail = "file size exceeds Silex int range";
            output->detailBytes = copyText(detail);
            output->detailLength = static_cast<std::int64_t>(detail.size());
            return;
        }
    }
    output->succeeded = true;
    output->errorKind = 0;
    output->fileKind = fileKind(status.type());
    output->size = static_cast<std::int64_t>(size);
    output->readonly = isReadonly(path, follow, status);
    output->detailBytes = nullptr;
    output->detailLength = 0;
}

extern "C" void silexNative_STD_FileSystem_native_canonicalize(
    const char* pathBytes,
    std::int64_t pathLength,
    SilexFileSystemPathResult* output
) {
    fs::path path;
    if (!nativePath(pathBytes, pathLength, path)) {
        output->succeeded = false;
        output->errorKind = nativeErrorKind();
        const auto detail = nativeErrorDetail();
        output->detailBytes = copyText(detail);
        output->detailLength = static_cast<std::int64_t>(detail.size());
        return;
    }
    std::error_code error;
    const auto canonical = fs::canonical(path, error);
    if (error) {
        output->succeeded = false;
        output->errorKind = errorKind(error);
        const auto detail = error.message();
        output->detailBytes = copyText(detail);
        output->detailLength = static_cast<std::int64_t>(detail.size());
        return;
    }
    std::string text;
    if (!utf8Path(canonical, text)) {
        output->succeeded = false;
        output->errorKind = nativeErrorKind();
        const auto detail = nativeErrorDetail();
        output->detailBytes = copyText(detail);
        output->detailLength = static_cast<std::int64_t>(detail.size());
        return;
    }
    output->succeeded = true;
    output->errorKind = 0;
    output->pathBytes = copyText(text);
    output->pathLength = static_cast<std::int64_t>(text.size());
    output->detailBytes = nullptr;
    output->detailLength = 0;
}

extern "C" void silexNative_STD_FileSystem_native_visit_entries(
    const char* pathBytes,
    std::int64_t pathLength,
    void (*visitor)(void*, std::int64_t, std::int64_t),
    void* visitorContext,
    SilexFileSystemOperationResult* output
) {
    fs::path path;
    if (!nativePath(pathBytes, pathLength, path)) {
        fail(output, nativeErrorKind(), nativeErrorDetail());
        return;
    }
    struct Entry { std::string name; std::int64_t kind; };
    std::vector<Entry> entries;
    std::error_code error;
    fs::directory_iterator iterator(path, error);
    if (error) {
        fail(output, errorKind(error), error.message());
        return;
    }
    const fs::directory_iterator end;
    while (iterator != end) {
        std::string name;
        if (!utf8Path(iterator->path().filename(), name) || !validUtf8(name)) {
            fail(output, kInvalidData, "directory entry name is not valid UTF-8");
            return;
        }
        const auto status = iterator->symlink_status(error);
        if (error) {
            fail(output, errorKind(error), error.message());
            return;
        }
        entries.push_back(Entry{std::move(name), fileKind(status.type())});
        iterator.increment(error);
        if (error) {
            fail(output, errorKind(error), error.message());
            return;
        }
    }
    std::sort(entries.begin(), entries.end(), [](const Entry& left, const Entry& right) {
        return byteLess(left.name, right.name);
    });
    for (const auto& entry : entries) {
        visitor(
            visitorContext,
            entry.kind,
            static_cast<std::int64_t>(entry.name.size())
        );
        for (const unsigned char byte : entry.name) {
            visitor(visitorContext, 0, byte);
        }
    }
    succeed(output);
}

extern "C" void silexNative_STD_FileSystem_native_create_directory(
    const char* pathBytes,
    std::int64_t pathLength,
    bool recursive,
    SilexFileSystemOperationResult* output
) {
    fs::path path;
    if (!nativePath(pathBytes, pathLength, path)) {
        fail(output, nativeErrorKind(), nativeErrorDetail());
        return;
    }
    std::error_code error;
    const bool created = recursive
        ? fs::create_directories(path, error)
        : fs::create_directory(path, error);
    if (error) {
        fail(output, errorKind(error), error.message());
        return;
    }
    if (created) {
        succeed(output);
        return;
    }
    if (recursive && fs::is_directory(fs::status(path, error)) && !error) {
        succeed(output);
        return;
    }
    fail(output, kAlreadyExists, "path already exists");
}

extern "C" void silexNative_STD_FileSystem_native_remove(
    const char* pathBytes,
    std::int64_t pathLength,
    bool directory,
    SilexFileSystemOperationResult* output
) {
    fs::path path;
    if (!nativePath(pathBytes, pathLength, path)) {
        fail(output, nativeErrorKind(), nativeErrorDetail());
        return;
    }
    std::error_code error;
    fs::file_status status;
    const bool exists = pathExists(path, status, error);
    if (error) {
        fail(output, errorKind(error), error.message());
        return;
    }
    if (!exists) {
        fail(output, kNotFound, "path does not exist");
        return;
    }
    if (directory) {
        if (status.type() != fs::file_type::directory) {
            fail(output, kNotDirectory, "path is not a directory");
            return;
        }
    } else if (status.type() == fs::file_type::directory) {
        fail(output, kIsDirectory, "path is a directory");
        return;
    }
    if (!fs::remove(path, error)) {
        if (error) fail(output, errorKind(error), error.message());
        else fail(output, kNotFound, "path does not exist");
        return;
    }
    succeed(output);
}

extern "C" void silexNative_STD_FileSystem_native_rename(
    const char* sourceBytes,
    std::int64_t sourceLength,
    const char* destinationBytes,
    std::int64_t destinationLength,
    SilexFileSystemOperationResult* output
) {
    fs::path source;
    fs::path destination;
    if (!nativePath(sourceBytes, sourceLength, source) ||
        !nativePath(destinationBytes, destinationLength, destination)) {
        fail(output, nativeErrorKind(), nativeErrorDetail());
        return;
    }
    std::error_code error;
    fs::file_status destinationStatus;
    if (pathExists(destination, destinationStatus, error)) {
        fail(output, kAlreadyExists, "destination already exists");
        return;
    }
    if (error) {
        fail(output, errorKind(error), error.message());
        return;
    }
    fs::rename(source, destination, error);
    if (error) {
        fail(output, errorKind(error), error.message());
        return;
    }
    succeed(output);
}

extern "C" void silexNative_STD_FileSystem_native_copy_file(
    const char* sourceBytes,
    std::int64_t sourceLength,
    const char* destinationBytes,
    std::int64_t destinationLength,
    bool replace,
    SilexFileSystemOperationResult* output
) {
    fs::path source;
    fs::path destination;
    if (!nativePath(sourceBytes, sourceLength, source) ||
        !nativePath(destinationBytes, destinationLength, destination)) {
        fail(output, nativeErrorKind(), nativeErrorDetail());
        return;
    }
    std::error_code error;
    const auto sourceStatus = fs::status(source, error);
    if (error) {
        fail(output, errorKind(error), error.message());
        return;
    }
    if (sourceStatus.type() == fs::file_type::not_found) {
        fail(output, kNotFound, "source does not exist");
        return;
    }
    if (sourceStatus.type() == fs::file_type::directory) {
        fail(output, kIsDirectory, "source is a directory");
        return;
    }
    fs::file_status destinationStatus;
    const bool destinationExists = pathExists(destination, destinationStatus, error);
    if (error) {
        fail(output, errorKind(error), error.message());
        return;
    }
    if (destinationExists) {
        if (!replace) {
            fail(output, kAlreadyExists, "destination already exists");
            return;
        }
        if (destinationStatus.type() == fs::file_type::directory) {
            fail(output, kIsDirectory, "destination is a directory");
            return;
        }
        if (!fs::remove(destination, error)) {
            if (error) fail(output, errorKind(error), error.message());
            else fail(output, kAlreadyExists, "destination could not be replaced");
            return;
        }
    }
    if (!fs::copy_file(source, destination, fs::copy_options::none, error)) {
        if (error) fail(output, errorKind(error), error.message());
        else fail(output, kAlreadyExists, "destination already exists");
        return;
    }
    succeed(output);
}

extern "C" void silexNative_STD_FileSystem_native_set_readonly(
    const char* pathBytes,
    std::int64_t pathLength,
    bool readonly,
    SilexFileSystemOperationResult* output
) {
    fs::path path;
    if (!nativePath(pathBytes, pathLength, path)) {
        fail(output, nativeErrorKind(), nativeErrorDetail());
        return;
    }
#if defined(_WIN32)
    std::error_code error;
    const auto target = fs::canonical(path, error);
    if (error) {
        fail(output, errorKind(error), error.message());
        return;
    }
    const auto attributes = GetFileAttributesW(target.c_str());
    if (attributes == INVALID_FILE_ATTRIBUTES) {
        fail(output, nativeErrorKind(), nativeErrorDetail());
        return;
    }
    const auto changed = readonly
        ? attributes | FILE_ATTRIBUTE_READONLY
        : attributes & ~FILE_ATTRIBUTE_READONLY;
    if (!SetFileAttributesW(target.c_str(), changed)) {
        fail(output, nativeErrorKind(), nativeErrorDetail());
        return;
    }
#else
    const auto writable = fs::perms::owner_write | fs::perms::group_write |
        fs::perms::others_write;
    std::error_code error;
    fs::permissions(
        path,
        writable,
        readonly ? fs::perm_options::remove : fs::perm_options::add,
        error
    );
    if (error) {
        fail(output, errorKind(error), error.message());
        return;
    }
#endif
    succeed(output);
}
