#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <optional>
#include <string>
#include <string_view>
#include <vector>

#include "PathCore.hpp"

#if !defined(SILEX_PATH_CORE_ONLY)
#include <SilexNative/STD.h>
#endif

namespace SilexPath {

Result Result::failure(std::string message) {
    Result result;
    result.succeeded = false;
    result.present = false;
    result.detail = std::move(message);
    return result;
}

Result Result::absent() {
    Result result;
    result.present = false;
    return result;
}

Result Result::textValue(std::string value) {
    Result result;
    result.text = std::move(value);
    return result;
}

Result Result::booleanValue(bool value) {
    Result result;
    result.boolean = value;
    return result;
}

namespace {

struct Parsed {
    bool succeeded = true;
    bool absolute = false;
    std::string root;
    std::vector<std::string> components;
    std::string detail;
};

bool isSeparator(char character, bool windows) {
    return character == '/' || (windows && character == '\\');
}

bool isAsciiLetter(char character) {
    return (character >= 'A' && character <= 'Z') || (character >= 'a' && character <= 'z');
}

Parsed fail(std::string detail) {
    Parsed result;
    result.succeeded = false;
    result.detail = std::move(detail);
    return result;
}

Parsed parse(std::string_view path, bool windows) {
    if (path.find('\0') != std::string_view::npos) return fail("path contains a null byte");

    Parsed result;
    std::size_t cursor = 0;
    if (!windows) {
        if (!path.empty() && path.front() == '/') {
            result.absolute = true;
            result.root = "/";
            while (cursor < path.size() && path[cursor] == '/') ++cursor;
        }
    } else if (path.size() >= 2 && isSeparator(path[0], true) && isSeparator(path[1], true)) {
        if (path.size() >= 3 && isSeparator(path[2], true)) return fail("Windows UNC root has too many leading separators");
        cursor = 2;
        const std::size_t server_start = cursor;
        while (cursor < path.size() && !isSeparator(path[cursor], true)) ++cursor;
        if (cursor == server_start || cursor == path.size()) return fail("Windows UNC root requires a server and share");
        const std::string server(path.substr(server_start, cursor - server_start));
        if (server == "?" || server == ".") return fail("internal Win32 device prefixes are not portable paths");
        while (cursor < path.size() && isSeparator(path[cursor], true)) ++cursor;
        const std::size_t share_start = cursor;
        while (cursor < path.size() && !isSeparator(path[cursor], true)) ++cursor;
        if (cursor == share_start) return fail("Windows UNC root requires a non-empty share");
        const std::string share(path.substr(share_start, cursor - share_start));
        result.absolute = true;
        result.root = "//" + server + "/" + share + "/";
        while (cursor < path.size() && isSeparator(path[cursor], true)) ++cursor;
    } else if (path.size() >= 2 && path[1] == ':') {
        if (!isAsciiLetter(path[0]) || path.size() < 3 || !isSeparator(path[2], true)) {
            return fail("Windows drive root must have the form C:/");
        }
        result.absolute = true;
        result.root = std::string{path[0]} + ":/";
        cursor = 3;
        while (cursor < path.size() && isSeparator(path[cursor], true)) ++cursor;
    } else if (!path.empty() && isSeparator(path.front(), true)) {
        return fail("Windows absolute path requires a drive or UNC root");
    }

    while (cursor < path.size()) {
        while (cursor < path.size() && isSeparator(path[cursor], windows)) ++cursor;
        if (cursor == path.size()) break;
        const std::size_t start = cursor;
        while (cursor < path.size() && !isSeparator(path[cursor], windows)) ++cursor;
        const std::string component(path.substr(start, cursor - start));
        if (component.empty() || component == ".") continue;
        if (component == "..") {
            if (!result.components.empty() && result.components.back() != "..") {
                result.components.pop_back();
            } else if (!result.absolute) {
                result.components.push_back(component);
            }
            continue;
        }
        result.components.push_back(component);
    }
    return result;
}

std::string render(const Parsed& parsed) {
    std::string output = parsed.root;
    for (const std::string& component : parsed.components) {
        if (!output.empty() && output.back() != '/') output += '/';
        output += component;
    }
    if (output.empty()) return ".";
    return output;
}

Result fromParsed(Parsed parsed) {
    if (!parsed.succeeded) return Result::failure(std::move(parsed.detail));
    return Result::textValue(render(parsed));
}

Result optionalText(std::optional<std::string> value) {
    if (!value.has_value()) return Result::absent();
    return Result::textValue(std::move(*value));
}

std::optional<std::string> finalName(const Parsed& parsed) {
    if (parsed.components.empty()) return std::nullopt;
    return parsed.components.back();
}

} // namespace

Result validate(std::string_view path, bool windows) {
    const Parsed parsed = parse(path, windows);
    if (!parsed.succeeded) return Result::failure(parsed.detail);
    return {};
}

Result normalize(std::string_view path, bool windows) {
    return fromParsed(parse(path, windows));
}

Result join(std::string_view base, std::string_view child, bool windows) {
    const Parsed parsed_base = parse(base, windows);
    if (!parsed_base.succeeded) return Result::failure("invalid base: " + parsed_base.detail);
    const Parsed parsed_child = parse(child, windows);
    if (!parsed_child.succeeded) return Result::failure("invalid child: " + parsed_child.detail);
    if (parsed_child.absolute) return Result::textValue(render(parsed_child));
    const std::string combined = render(parsed_base) + "/" + std::string(child);
    return normalize(combined, windows);
}

Result parent(std::string_view path, bool windows) {
    Parsed parsed = parse(path, windows);
    if (!parsed.succeeded) return Result::failure(std::move(parsed.detail));
    if (parsed.components.empty()) return Result::absent();
    parsed.components.pop_back();
    if (!parsed.absolute && parsed.components.empty()) return Result::textValue(".");
    return Result::textValue(render(parsed));
}

Result name(std::string_view path, bool windows) {
    const Parsed parsed = parse(path, windows);
    if (!parsed.succeeded) return Result::failure(parsed.detail);
    return optionalText(finalName(parsed));
}

Result stem(std::string_view path, bool windows) {
    const Parsed parsed = parse(path, windows);
    if (!parsed.succeeded) return Result::failure(parsed.detail);
    const std::optional<std::string> path_name = finalName(parsed);
    if (!path_name.has_value()) return Result::absent();
    const std::size_t dot = path_name->find_last_of('.');
    if (dot == std::string::npos || dot == 0 || dot + 1 == path_name->size()) return Result::textValue(*path_name);
    return Result::textValue(path_name->substr(0, dot));
}

Result extension(std::string_view path, bool windows) {
    const Parsed parsed = parse(path, windows);
    if (!parsed.succeeded) return Result::failure(parsed.detail);
    const std::optional<std::string> path_name = finalName(parsed);
    if (!path_name.has_value()) return Result::absent();
    const std::size_t dot = path_name->find_last_of('.');
    if (dot == std::string::npos || dot == 0 || dot + 1 == path_name->size()) return Result::absent();
    return Result::textValue(path_name->substr(dot + 1));
}

Result isAbsolute(std::string_view path, bool windows) {
    const Parsed parsed = parse(path, windows);
    if (!parsed.succeeded) return Result::failure(parsed.detail);
    return Result::booleanValue(parsed.absolute);
}

} // namespace SilexPath

#if !defined(SILEX_PATH_CORE_ONLY) && defined(SILEX_NATIVE_TRANSPORT_SILEXNATIVE_STD_PATH_NATIVEPATHRESULT)
namespace {

std::string textView(const char* bytes, std::int64_t length) {
    if (length == 0) return {};
    return {bytes, static_cast<std::size_t>(length)};
}

void setText(char*& bytes, std::int64_t& length, const std::string& text) {
    if (text.empty()) {
        bytes = nullptr;
        length = 0;
        return;
    }
    bytes = static_cast<char*>(std::malloc(text.size()));
    if (bytes != nullptr) std::memcpy(bytes, text.data(), text.size());
    length = static_cast<std::int64_t>(text.size());
}

void writeResult(const SilexPath::Result& result, SilexNative_STD_Path_NativePathResult* output) {
    output->succeeded = result.succeeded;
    output->present = result.present;
    output->boolean = result.boolean;
    setText(output->text_bytes, output->text_length, result.text);
    setText(output->detail_bytes, output->detail_length, result.detail);
}

} // namespace

extern "C" bool silexNative_STD_Path_native_windows_semantics() {
#if defined(_WIN32)
    return true;
#else
    return false;
#endif
}

#define SILEX_PATH_UNARY_WRAPPER(native_name, core_name) \
    extern "C" void silexNative_STD_Path_native_##native_name( \
        const char* bytes, std::int64_t length, bool windows, SilexNative_STD_Path_NativePathResult* output) { \
        writeResult(SilexPath::core_name(textView(bytes, length), windows), output); \
    }

SILEX_PATH_UNARY_WRAPPER(validate, validate)
SILEX_PATH_UNARY_WRAPPER(normalize, normalize)
SILEX_PATH_UNARY_WRAPPER(parent, parent)
SILEX_PATH_UNARY_WRAPPER(name, name)
SILEX_PATH_UNARY_WRAPPER(stem, stem)
SILEX_PATH_UNARY_WRAPPER(extension, extension)
SILEX_PATH_UNARY_WRAPPER(is_absolute, isAbsolute)

extern "C" void silexNative_STD_Path_native_join(
    const char* base_bytes,
    std::int64_t base_length,
    const char* child_bytes,
    std::int64_t child_length,
    bool windows,
    SilexNative_STD_Path_NativePathResult* output
) {
    writeResult(SilexPath::join(textView(base_bytes, base_length), textView(child_bytes, child_length), windows), output);
}
#endif
