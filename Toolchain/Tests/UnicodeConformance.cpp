#include <cstdint>
#include <cstdlib>
#include <fstream>
#include <iostream>
#include <sstream>
#include <string>
#include <string_view>
#include <vector>

#include "../../Library/STD/@Native/Unicode/utf8proc/utf8proc.h"

extern "C" void silexNative_STD_Text_native_normalize(
    const char*, std::int64_t, std::int64_t, char**, std::int64_t*
);
extern "C" void silexNative_STD_Text_native_lowercase(
    const char*, std::int64_t, char**, std::int64_t*
);
extern "C" void silexNative_STD_Text_native_uppercase(
    const char*, std::int64_t, char**, std::int64_t*
);
extern "C" void silexNative_STD_Text_native_case_fold(
    const char*, std::int64_t, char**, std::int64_t*
);
extern "C" void silexNative_STD_Text_Grapheme_native_visit_boundaries(
    const char*, std::int64_t, void (*)(void*, std::int64_t), void*
);

namespace {

using NativeTransform = void (*)(const char*, std::int64_t, char**, std::int64_t*);

std::string transformed(std::string_view input, NativeTransform transform) {
    char* output = nullptr;
    std::int64_t length = 0;
    transform(input.data(), static_cast<std::int64_t>(input.size()), &output, &length);
    std::string result(output, static_cast<std::size_t>(length));
    std::free(output);
    return result;
}

std::string normalized(std::string_view input, std::int64_t form) {
    char* output = nullptr;
    std::int64_t length = 0;
    silexNative_STD_Text_native_normalize(
        input.data(), static_cast<std::int64_t>(input.size()), form, &output, &length
    );
    std::string result(output, static_cast<std::size_t>(length));
    std::free(output);
    return result;
}

std::vector<std::string> fields(std::string_view line) {
    std::vector<std::string> result;
    std::size_t start = 0;
    while (start <= line.size()) {
        const auto end = line.find(';', start);
        auto field = line.substr(start, end == std::string_view::npos ? line.size() - start : end - start);
        const auto first = field.find_first_not_of(" \t\r\n");
        const auto last = field.find_last_not_of(" \t\r\n");
        result.emplace_back(first == std::string_view::npos ? std::string_view{} : field.substr(first, last - first + 1));
        if (end == std::string_view::npos) break;
        start = end + 1;
    }
    return result;
}

std::string utf8(std::string_view sequence) {
    std::istringstream input{std::string(sequence)};
    std::string token;
    std::string result;
    while (input >> token) {
        const auto codepoint = static_cast<utf8proc_int32_t>(std::stoul(token, nullptr, 16));
        utf8proc_uint8_t encoded[4];
        const auto length = utf8proc_encode_char(codepoint, encoded);
        result.append(reinterpret_cast<const char*>(encoded), static_cast<std::size_t>(length));
    }
    return result;
}

bool checkNormalization(const char* path) {
    std::ifstream input(path);
    std::string line;
    std::size_t lineNumber = 0;
    while (std::getline(input, line)) {
        ++lineNumber;
        const auto content = fields(std::string_view(line).substr(0, line.find('#')));
        if (content.size() < 5 || content[0].empty() || content[0].front() == '@') continue;
        const std::string c1 = utf8(content[0]);
        const std::string c2 = utf8(content[1]);
        const std::string c3 = utf8(content[2]);
        const std::string c4 = utf8(content[3]);
        const std::string c5 = utf8(content[4]);
        const bool valid =
            normalized(c1, 0) == c2 && normalized(c2, 0) == c2 &&
            normalized(c3, 0) == c2 && normalized(c4, 0) == c4 && normalized(c5, 0) == c4 &&
            normalized(c1, 1) == c3 && normalized(c2, 1) == c3 &&
            normalized(c3, 1) == c3 && normalized(c4, 1) == c5 && normalized(c5, 1) == c5 &&
            normalized(c1, 2) == c4 && normalized(c2, 2) == c4 &&
            normalized(c3, 2) == c4 && normalized(c4, 2) == c4 && normalized(c5, 2) == c4 &&
            normalized(c1, 3) == c5 && normalized(c2, 3) == c5 &&
            normalized(c3, 3) == c5 && normalized(c4, 3) == c5 && normalized(c5, 3) == c5;
        if (!valid) {
            std::cerr << path << ':' << lineNumber << ": normalization conformance failure\n";
            return false;
        }
    }
    return input.eof();
}

bool checkCaseFolding(const char* path) {
    std::ifstream input(path);
    std::string line;
    std::size_t lineNumber = 0;
    while (std::getline(input, line)) {
        ++lineNumber;
        const auto content = fields(std::string_view(line).substr(0, line.find('#')));
        if (content.size() < 3 || content[0].empty() || (content[1] != "C" && content[1] != "F")) continue;
        const auto source = utf8(content[0]);
        const auto expected = utf8(content[2]);
        if (transformed(source, silexNative_STD_Text_native_case_fold) != expected) {
            std::cerr << path << ':' << lineNumber << ": case-folding conformance failure\n";
            return false;
        }
    }
    return input.eof();
}

bool checkSpecialCasing(const char* path) {
    std::ifstream input(path);
    std::string line;
    std::size_t lineNumber = 0;
    while (std::getline(input, line)) {
        ++lineNumber;
        const auto content = fields(std::string_view(line).substr(0, line.find('#')));
        if (content.size() < 5 || content[0].empty() || !content[4].empty()) continue;
        const auto source = utf8(content[0]);
        if (transformed(source, silexNative_STD_Text_native_lowercase) != utf8(content[1]) ||
            transformed(source, silexNative_STD_Text_native_uppercase) != utf8(content[3])) {
            std::cerr << path << ':' << lineNumber << ": special-casing conformance failure\n";
            return false;
        }
    }
    return input.eof();
}

void collectBoundary(void* context, std::int64_t offset) {
    static_cast<std::vector<std::int64_t>*>(context)->push_back(offset);
}

bool checkGraphemeBreaks(const char* path) {
    std::ifstream input(path);
    std::string line;
    std::size_t lineNumber = 0;
    while (std::getline(input, line)) {
        ++lineNumber;
        const auto comment = line.find('#');
        std::istringstream tokens(line.substr(0, comment));
        std::string marker;
        std::string code;
        std::string text;
        std::vector<std::int64_t> expected;
        while (tokens >> marker) {
            if (marker == "÷") expected.push_back(static_cast<std::int64_t>(text.size()));
            if (!(tokens >> code)) break;
            text += utf8(code);
        }
        if (expected.empty()) continue;
        std::vector<std::int64_t> actual{0};
        silexNative_STD_Text_Grapheme_native_visit_boundaries(
            text.data(), static_cast<std::int64_t>(text.size()), collectBoundary, &actual
        );
        if (actual != expected) {
            std::cerr << path << ':' << lineNumber << ": grapheme-break conformance failure\n";
            return false;
        }
    }
    return input.eof();
}

} // namespace

int main(int argumentCount, char** arguments) {
    if (argumentCount != 5) return 2;
    if (std::string_view(utf8proc_unicode_version()) != "17.0.0") return 3;
    if (!checkNormalization(arguments[1])) return 4;
    if (!checkCaseFolding(arguments[2])) return 5;
    if (!checkSpecialCasing(arguments[3])) return 6;
    if (!checkGraphemeBreaks(arguments[4])) return 10;
    if (transformed("ΟΣ", silexNative_STD_Text_native_lowercase) != "ος") return 7;
    if (transformed("ΟΣΑ", silexNative_STD_Text_native_lowercase) != "οσα") return 8;
    const std::string embeddedNull("\0", 1);
    if (normalized(embeddedNull, 0) != embeddedNull) return 9;
    return 0;
}
