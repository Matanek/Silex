#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <string>
#include <SilexNative/NativeStructureStrings.h>

namespace {

// -----------------------------------------------------------------------------

char* copyBytes(const char* bytes, std::int64_t length) {
    if (length == 0) return nullptr;
    auto* copy = static_cast<char*>(std::malloc(static_cast<std::size_t>(length)));
    if (copy != nullptr) std::memcpy(copy, bytes, static_cast<std::size_t>(length));
    return copy;
}

void setText(char*& outputBytes, std::int64_t& outputLength, const char* bytes, std::int64_t length) {
    outputBytes = copyBytes(bytes, length);
    outputLength = length;
}

void setAllocatedFields(SilexNative_NativeStructureStrings_NativeMessage* output) {
    constexpr char title[] = "allocated first";
    constexpr char detail[] = "allocated second";
    setText(output->title_bytes, output->title_length, title, sizeof(title) - 1);
    setText(output->detail_bytes, output->detail_length, detail, sizeof(detail) - 1);
}

// -----------------------------------------------------------------------------

} // namespace

extern "C" void silexNative_NativeStructureStrings_native_read(
    int64_t sequence,
    SilexNative_NativeStructureStrings_NativeMessage* output
) {
    const std::string title = "événement 🌟 " + std::to_string(sequence);
    constexpr char detail[] = {'A', '\0', 'B'};
    output->sequence = sequence;
    setText(output->title_bytes, output->title_length, title.data(), static_cast<std::int64_t>(title.size()));
    setText(output->detail_bytes, output->detail_length, detail, sizeof(detail));
    output->empty_bytes = nullptr;
    output->empty_length = 0;
}

extern "C" void silexNative_NativeStructureStrings_native_negative_length(
    SilexNative_NativeStructureStrings_NativeMessage* output
) {
    setAllocatedFields(output);
    output->detail_length = -1;
}

extern "C" void silexNative_NativeStructureStrings_native_null_with_positive_length(
    SilexNative_NativeStructureStrings_NativeMessage* output
) {
    setAllocatedFields(output);
    std::free(output->detail_bytes);
    output->detail_bytes = nullptr;
    output->detail_length = 1;
}

extern "C" void silexNative_NativeStructureStrings_native_invalid_utf8(
    SilexNative_NativeStructureStrings_NativeMessage* output
) {
    setAllocatedFields(output);
    output->detail_bytes[0] = static_cast<char>(0xff);
    output->detail_length = 1;
}
