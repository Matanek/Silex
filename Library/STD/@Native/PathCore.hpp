#pragma once

#include <string>
#include <string_view>

namespace SilexPath {

struct Result {
    bool succeeded = true;
    bool present = true;
    bool boolean = false;
    std::string text;
    std::string detail;

    static Result failure(std::string message);
    static Result absent();
    static Result textValue(std::string value);
    static Result booleanValue(bool value);
};

Result validate(std::string_view path, bool windows);
Result normalize(std::string_view path, bool windows);
Result join(std::string_view base, std::string_view child, bool windows);
Result parent(std::string_view path, bool windows);
Result name(std::string_view path, bool windows);
Result stem(std::string_view path, bool windows);
Result extension(std::string_view path, bool windows);
Result isAbsolute(std::string_view path, bool windows);

} // namespace SilexPath
