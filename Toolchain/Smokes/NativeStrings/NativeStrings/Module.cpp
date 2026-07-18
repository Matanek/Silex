#include <cstddef>
#include <cstdint>
#include <cstdlib>
#include <cstring>

namespace {

char* copyBytes(const char* bytes, std::int64_t length) {
    if (length == 0) return nullptr;
    auto* copy = static_cast<char*>(std::malloc(static_cast<std::size_t>(length)));
    if (copy != nullptr) std::memcpy(copy, bytes, static_cast<std::size_t>(length));
    return copy;
}

}

extern "C" void silexNative_NativeStrings_native_empty(
    char** output_bytes,
    std::int64_t* output_length
) {
    *output_bytes = nullptr;
    *output_length = 0;
}

extern "C" void silexNative_NativeStrings_native_unicode(
    char** output_bytes,
    std::int64_t* output_length
) {
    constexpr char text[] = "hé🌟";
    *output_bytes = copyBytes(text, sizeof(text) - 1);
    *output_length = sizeof(text) - 1;
}

extern "C" void silexNative_NativeStrings_native_nul(
    char** output_bytes,
    std::int64_t* output_length
) {
    constexpr char text[] = { 'A', '\0', 'B' };
    *output_bytes = copyBytes(text, sizeof(text));
    *output_length = sizeof(text);
}

extern "C" void silexNative_NativeStrings_native_next(
    char** output_bytes,
    std::int64_t* output_length
) {
    static std::int64_t call_count = 0;
    call_count += 1;
    constexpr char first[] = "first";
    constexpr char second[] = "second";
    const auto* text = call_count == 1 ? first : second;
    const auto length = call_count == 1 ? sizeof(first) - 1 : sizeof(second) - 1;
    *output_bytes = copyBytes(text, length);
    *output_length = length;
}

extern "C" void silexNative_NativeStrings_native_negative_length(
    char** output_bytes,
    std::int64_t* output_length
) {
    constexpr char text[] = "x";
    *output_bytes = copyBytes(text, sizeof(text) - 1);
    *output_length = -1;
}

extern "C" void silexNative_NativeStrings_native_null_with_positive_length(
    char** output_bytes,
    std::int64_t* output_length
) {
    *output_bytes = nullptr;
    *output_length = 1;
}

extern "C" void silexNative_NativeStrings_native_invalid_utf8(
    char** output_bytes,
    std::int64_t* output_length
) {
    constexpr char text[] = { static_cast<char>(0xc3), static_cast<char>(0x28) };
    *output_bytes = copyBytes(text, sizeof(text));
    *output_length = sizeof(text);
}
