#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <SilexNative/NativeByteViews.h>

namespace {

// -----------------------------------------------------------------------------

void setFailure(
    SilexNative_NativeByteViews_native_write_blockResult* output,
    const char* text
) {
    const auto length = static_cast<std::int64_t>(std::strlen(text));
    output->failure_bytes = static_cast<char*>(
        std::malloc(static_cast<std::size_t>(length))
    );
    if (output->failure_bytes != nullptr) {
        std::memcpy(output->failure_bytes, text, static_cast<std::size_t>(length));
    }
    output->failure_length = length;
}

std::uint64_t checksum(const std::uint8_t* bytes, std::int64_t length) {
    std::uint64_t result = 0;
    for (std::int64_t index = 0; index < length; index += 1) {
        result += bytes[index];
    }
    return result;
}

// -----------------------------------------------------------------------------

} // namespace

extern "C" std::uint64_t silexNative_NativeByteViews_native_checksum(
    const std::uint8_t* bytes,
    std::int64_t length
) {
    if (length == 0) return 0;
    return checksum(bytes, length);
}

extern "C" std::uint64_t silexNative_NativeByteViews_native_fixed_checksum(
    const std::uint8_t* bytes,
    std::int64_t length
) {
    return checksum(bytes, length);
}

extern "C" void silexNative_NativeByteViews_native_write_block(
    const std::uint8_t* bytes,
    std::int64_t length,
    SilexNative_NativeByteViews_native_write_blockResult* output
) {
    if (length != 4 || bytes == nullptr || bytes[0] != 0 ||
        bytes[1] != 17 || bytes[2] != 0 || bytes[3] != 255) {
        output->tag = SilexNative_NativeByteViews_native_write_blockResultTag_failure;
        setFailure(output, "unexpected block");
        return;
    }
    output->tag = SilexNative_NativeByteViews_native_write_blockResultTag_success;
}
