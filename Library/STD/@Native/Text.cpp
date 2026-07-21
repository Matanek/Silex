#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <stdexcept>
#include <vector>

#include "Unicode/CaseData.hpp"
#include "Unicode/utf8proc/utf8proc.h"

namespace {

template <typename T>
T* copyBytes(const T* source, std::int64_t length) {
    if (length <= 0) return nullptr;
    auto* result = static_cast<T*>(std::malloc(static_cast<std::size_t>(length)));
    if (result != nullptr) {
        std::memcpy(result, source, static_cast<std::size_t>(length));
    }
    return result;
}

template <typename T, std::size_t Size>
const T* findMapping(const T (&mappings)[Size], std::uint32_t codepoint) {
    std::size_t first = 0;
    std::size_t last = Size;
    while (first < last) {
        const auto middle = first + (last - first) / 2;
        if (mappings[middle].codepoint < codepoint) {
            first = middle + 1;
        } else {
            last = middle;
        }
    }
    return first < Size && mappings[first].codepoint == codepoint ? &mappings[first] : nullptr;
}

template <std::size_t Size>
bool inRanges(const silex::unicode::CodepointRange (&ranges)[Size], std::uint32_t codepoint) {
    std::size_t first = 0;
    std::size_t last = Size;
    while (first < last) {
        const auto middle = first + (last - first) / 2;
        if (ranges[middle].last < codepoint) {
            first = middle + 1;
        } else {
            last = middle;
        }
    }
    return first < Size && ranges[first].first <= codepoint;
}

std::vector<std::uint32_t> decodeScalars(const char* text, std::int64_t length) {
    std::vector<std::uint32_t> result;
    std::int64_t offset = 0;
    while (offset < length) {
        utf8proc_int32_t codepoint = 0;
        const auto consumed = utf8proc_iterate(
            reinterpret_cast<const utf8proc_uint8_t*>(text + offset),
            static_cast<utf8proc_ssize_t>(length - offset),
            &codepoint
        );
        if (consumed < 0) throw std::runtime_error("invalid UTF-8 string passed to STD.Text");
        result.push_back(static_cast<std::uint32_t>(codepoint));
        offset += consumed;
    }
    return result;
}

struct PositionedScalar {
    std::uint32_t codepoint;
    std::int64_t byteOffset;
};

std::vector<PositionedScalar> decodePositionedScalars(const char* text, std::int64_t length) {
    std::vector<PositionedScalar> result;
    std::int64_t offset = 0;
    while (offset < length) {
        utf8proc_int32_t codepoint = 0;
        const auto consumed = utf8proc_iterate(
            reinterpret_cast<const utf8proc_uint8_t*>(text + offset),
            static_cast<utf8proc_ssize_t>(length - offset),
            &codepoint
        );
        if (consumed < 0) throw std::runtime_error("invalid UTF-8 string passed to STD.Text");
        result.push_back({static_cast<std::uint32_t>(codepoint), offset});
        offset += consumed;
    }
    return result;
}

bool isFinalSigma(const std::vector<std::uint32_t>& values, std::size_t index) {
    bool precededByCased = false;
    auto before = index;
    while (before > 0) {
        --before;
        const auto codepoint = values[before];
        if (inRanges(silex::unicode::caseIgnorableRanges, codepoint)) continue;
        precededByCased = inRanges(silex::unicode::casedRanges, codepoint);
        break;
    }
    if (!precededByCased) return false;
    for (auto after = index + 1; after < values.size(); ++after) {
        const auto codepoint = values[after];
        if (inRanges(silex::unicode::caseIgnorableRanges, codepoint)) continue;
        return !inRanges(silex::unicode::casedRanges, codepoint);
    }
    return true;
}

void appendEncoded(std::vector<std::uint8_t>& output, std::uint32_t codepoint) {
    utf8proc_uint8_t encoded[4];
    const auto length = utf8proc_encode_char(static_cast<utf8proc_int32_t>(codepoint), encoded);
    output.insert(output.end(), encoded, encoded + length);
}

std::vector<std::uint8_t> mapCase(const char* text, std::int64_t length, bool uppercase) {
    const auto input = decodeScalars(text, length);
    std::vector<std::uint8_t> output;
    output.reserve(static_cast<std::size_t>(length));
    for (std::size_t index = 0; index < input.size(); ++index) {
        const auto codepoint = input[index];
        if (!uppercase && codepoint == 0x03A3 && isFinalSigma(input, index)) {
            appendEncoded(output, 0x03C2);
            continue;
        }
        const auto* mapping = uppercase
            ? findMapping(silex::unicode::uppercaseMappings, codepoint)
            : findMapping(silex::unicode::lowercaseMappings, codepoint);
        if (mapping != nullptr) {
            const auto* values = uppercase
                ? silex::unicode::uppercaseValues
                : silex::unicode::lowercaseValues;
            for (std::size_t part = 0; part < mapping->length; ++part) {
                appendEncoded(output, values[mapping->offset + part]);
            }
            continue;
        }
        appendEncoded(
            output,
            static_cast<std::uint32_t>(uppercase
                ? utf8proc_toupper(static_cast<utf8proc_int32_t>(codepoint))
                : utf8proc_tolower(static_cast<utf8proc_int32_t>(codepoint)))
        );
    }
    return output;
}

void returnBytes(
    const std::vector<std::uint8_t>& bytes,
    char** outputBytes,
    std::int64_t* outputLength
) {
    *outputBytes = copyBytes(reinterpret_cast<const char*>(bytes.data()), bytes.size());
    *outputLength = static_cast<std::int64_t>(bytes.size());
}

void returnMapped(
    const char* text,
    std::int64_t length,
    utf8proc_option_t options,
    char** outputBytes,
    std::int64_t* outputLength
) {
    utf8proc_uint8_t* mapped = nullptr;
    const auto resultLength = utf8proc_map(
        reinterpret_cast<const utf8proc_uint8_t*>(text),
        static_cast<utf8proc_ssize_t>(length),
        &mapped,
        options
    );
    if (resultLength < 0) throw std::runtime_error(utf8proc_errmsg(resultLength));
    *outputBytes = reinterpret_cast<char*>(mapped);
    *outputLength = static_cast<std::int64_t>(resultLength);
}

} // namespace

extern "C" void silexNative_STD_Text_native_normalize(
    const char* text,
    std::int64_t length,
    std::int64_t form,
    char** outputBytes,
    std::int64_t* outputLength
) {
    auto options = UTF8PROC_STABLE;
    switch (form) {
        case 0: options = static_cast<utf8proc_option_t>(options | UTF8PROC_COMPOSE); break;
        case 1: options = static_cast<utf8proc_option_t>(options | UTF8PROC_DECOMPOSE); break;
        case 2: options = static_cast<utf8proc_option_t>(options | UTF8PROC_COMPOSE | UTF8PROC_COMPAT); break;
        case 3: options = static_cast<utf8proc_option_t>(options | UTF8PROC_DECOMPOSE | UTF8PROC_COMPAT); break;
        default: throw std::runtime_error("invalid Unicode normalization form");
    }
    returnMapped(text, length, options, outputBytes, outputLength);
}

extern "C" void silexNative_STD_Text_native_lowercase(
    const char* text,
    std::int64_t length,
    char** outputBytes,
    std::int64_t* outputLength
) {
    returnBytes(mapCase(text, length, false), outputBytes, outputLength);
}

extern "C" void silexNative_STD_Text_native_uppercase(
    const char* text,
    std::int64_t length,
    char** outputBytes,
    std::int64_t* outputLength
) {
    returnBytes(mapCase(text, length, true), outputBytes, outputLength);
}

extern "C" void silexNative_STD_Text_native_case_fold(
    const char* text,
    std::int64_t length,
    char** outputBytes,
    std::int64_t* outputLength
) {
    returnMapped(
        text,
        length,
        static_cast<utf8proc_option_t>(UTF8PROC_STABLE | UTF8PROC_CASEFOLD),
        outputBytes,
        outputLength
    );
}

extern "C" void silexNative_STD_Text_Grapheme_native_visit_boundaries(
    const char* text,
    std::int64_t length,
    void (*visitor)(void*, std::int64_t),
    void* visitorContext
) {
    const auto scalars = decodePositionedScalars(text, length);
    utf8proc_int32_t state = 0;
    for (std::size_t index = 1; index < scalars.size(); ++index) {
        if (utf8proc_grapheme_break_stateful(
                static_cast<utf8proc_int32_t>(scalars[index - 1].codepoint),
                static_cast<utf8proc_int32_t>(scalars[index].codepoint),
                &state
            )) {
            visitor(visitorContext, scalars[index].byteOffset);
        }
    }
    if (length > 0) visitor(visitorContext, length);
}

extern "C" void silexNative_STD_Text_Grapheme_native_slice(
    const char* text,
    std::int64_t length,
    std::int64_t start,
    std::int64_t end,
    char** outputBytes,
    std::int64_t* outputLength
) {
    if (start < 0 || end < start || end > length) {
        throw std::runtime_error("invalid grapheme byte boundary");
    }
    *outputLength = end - start;
    *outputBytes = copyBytes(text + start, *outputLength);
}

extern "C" void silexNative_STD_Text_UTF8_native_bytes(
    const char* text,
    std::int64_t length,
    std::uint8_t** output_bytes,
    std::int64_t* output_length
) {
    *output_bytes = copyBytes(reinterpret_cast<const std::uint8_t*>(text), length);
    *output_length = length;
}

extern "C" void silexNative_STD_Text_UTF8_native_string(
    const std::uint8_t* bytes,
    std::int64_t length,
    char** output_bytes,
    std::int64_t* output_length
) {
    *output_bytes = copyBytes(reinterpret_cast<const char*>(bytes), length);
    *output_length = length;
}
