#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <SilexNative/NativeByteBuffers.h>

namespace {

std::uint8_t* copyBytes(const std::uint8_t* bytes, std::int64_t length) {
    if (length == 0) return nullptr;
    auto* result = static_cast<std::uint8_t*>(std::malloc(static_cast<std::size_t>(length)));
    if (result != nullptr) std::memcpy(result, bytes, static_cast<std::size_t>(length));
    return result;
}

} // namespace

extern "C" void silexNative_NativeByteBuffers_native_compress(
    const std::uint8_t* bytes,
    std::int64_t length,
    std::uint8_t** outputBytes,
    std::int64_t* outputLength
) {
    *outputBytes = copyBytes(bytes, length);
    *outputLength = length;
}

extern "C" void silexNative_NativeByteBuffers_native_empty(
    std::uint8_t** outputBytes,
    std::int64_t* outputLength
) {
    *outputBytes = nullptr;
    *outputLength = 0;
}

extern "C" void silexNative_NativeByteBuffers_native_large(
    std::uint8_t** outputBytes,
    std::int64_t* outputLength
) {
    constexpr std::int64_t length = 1024;
    auto* bytes = static_cast<std::uint8_t*>(std::malloc(static_cast<std::size_t>(length)));
    for (std::int64_t index = 0; index < length; index += 1) bytes[index] = static_cast<std::uint8_t>(index);
    *outputBytes = bytes;
    *outputLength = length;
}

extern "C" void silexNative_NativeByteBuffers_native_read(
    std::int64_t sequence,
    SilexNative_NativeByteBuffers_native_readResult* output
) {
    if (sequence == 2) {
        output->tag = SilexNative_NativeByteBuffers_native_readResultTag_failure;
        output->failure_bytes = nullptr;
        output->failure_length = 9;
        output->failure_bytes = static_cast<char*>(std::malloc(9));
        std::memcpy(output->failure_bytes, "not found", 9);
        return;
    }
    const std::uint8_t bytes[] = {0, 255, static_cast<std::uint8_t>(sequence), 0};
    output->tag = SilexNative_NativeByteBuffers_native_readResultTag_success;
    output->success_bytes = copyBytes(bytes, 4);
    output->success_length = 4;
}

extern "C" void silexNative_NativeByteBuffers_native_negative_length(
    std::uint8_t** outputBytes,
    std::int64_t* outputLength
) {
    const std::uint8_t byte = 7;
    *outputBytes = copyBytes(&byte, 1);
    *outputLength = -1;
}

extern "C" void silexNative_NativeByteBuffers_native_null_with_positive_length(
    std::uint8_t** outputBytes,
    std::int64_t* outputLength
) {
    *outputBytes = nullptr;
    *outputLength = 1;
}
