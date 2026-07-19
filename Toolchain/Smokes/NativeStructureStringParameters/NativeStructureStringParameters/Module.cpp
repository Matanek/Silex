#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <string>
#include <SilexNative/NativeStructureStringParameters.h>

namespace {

// -----------------------------------------------------------------------------

char* copyBytes(const char* bytes, std::int64_t length) {
    if (length == 0) return nullptr;
    auto* copy = static_cast<char*>(std::malloc(static_cast<std::size_t>(length)));
    if (copy != nullptr) std::memcpy(copy, bytes, static_cast<std::size_t>(length));
    return copy;
}

std::string stringView(const char* bytes, std::int64_t length) {
    if (length == 0) return {};
    return {bytes, static_cast<std::size_t>(length)};
}

void setOwnedText(char*& outputBytes, std::int64_t& outputLength, const std::string& text) {
    outputBytes = copyBytes(text.data(), static_cast<std::int64_t>(text.size()));
    outputLength = static_cast<std::int64_t>(text.size());
}

// -----------------------------------------------------------------------------

} // namespace

extern "C" void silexNative_NativeStructureStringParameters_native_round_trip(
    const SilexNative_NativeStructureStringParameters_NativeRequestInput* request,
    std::int64_t sequence,
    SilexNative_NativeStructureStringParameters_NativeRequest* output
) {
    const std::string path = stringView(request->path_bytes, request->path_length);
    const std::string label = stringView(request->label_bytes, request->label_length);
    const std::string empty = stringView(request->empty_bytes, request->empty_length);
    setOwnedText(output->path_bytes, output->path_length, path);
    setOwnedText(output->label_bytes, output->label_length, label + " #" + std::to_string(sequence));
    setOwnedText(output->empty_bytes, output->empty_length, empty);
    output->mode = request->mode + sequence;
}
