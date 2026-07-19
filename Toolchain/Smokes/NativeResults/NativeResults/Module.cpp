#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <string>
#include <SilexNative/NativeResults.h>

namespace {

// -----------------------------------------------------------------------------

char* copyText(const std::string& text) {
    if (text.empty()) return nullptr;
    auto* bytes = static_cast<char*>(std::malloc(text.size()));
    if (bytes != nullptr) std::memcpy(bytes, text.data(), text.size());
    return bytes;
}

void setText(char*& bytes, std::int64_t& length, const std::string& text) {
    bytes = copyText(text);
    length = static_cast<std::int64_t>(text.size());
}

std::string textView(const char* bytes, std::int64_t length) {
    if (length == 0) return {};
    return {bytes, static_cast<std::size_t>(length)};
}

// -----------------------------------------------------------------------------

} // namespace

extern "C" void silexNative_NativeResults_native_open(
    const char* pathBytes,
    std::int64_t pathLength,
    bool succeeds,
    SilexNative_NativeResults_native_openResult* output
) {
    const std::string path = textView(pathBytes, pathLength);
    if (succeeds) {
        output->tag = SilexNative_NativeResults_native_openResultTag_success;
        output->success_value.handle = 42;
        setText(output->success_value.path_bytes, output->success_value.path_length, path);
        return;
    }
    output->tag = SilexNative_NativeResults_native_openResultTag_failure;
    setText(output->failure_bytes, output->failure_length, "missing:" + path);
}

extern "C" void silexNative_NativeResults_native_save(
    bool succeeds,
    SilexNative_NativeResults_native_saveResult* output
) {
    if (succeeds) {
        output->tag = SilexNative_NativeResults_native_saveResultTag_success;
        return;
    }
    output->tag = SilexNative_NativeResults_native_saveResultTag_failure;
    setText(output->failure_bytes, output->failure_length, "denied");
}

extern "C" void silexNative_NativeResults_native_optional(
    std::int64_t mode,
    SilexNative_NativeResults_native_optionalResult* output
) {
    if (mode < 0) {
        output->tag = SilexNative_NativeResults_native_optionalResultTag_failure;
        setText(output->failure_bytes, output->failure_length, "negative");
        return;
    }
    output->tag = SilexNative_NativeResults_native_optionalResultTag_success;
    output->success_present = mode != 0;
    output->success_value = mode;
}

extern "C" void silexNative_NativeResults_native_invalid_tag(
    SilexNative_NativeResults_native_invalid_tagResult* output
) {
    output->tag = static_cast<SilexNative_NativeResults_native_invalid_tagResultTag>(7);
}

extern "C" void silexNative_NativeResults_native_inactive_owned(
    SilexNative_NativeResults_native_inactive_ownedResult* output
) {
    output->tag = SilexNative_NativeResults_native_inactive_ownedResultTag_success;
    output->success_value = 1;
    setText(output->failure_bytes, output->failure_length, "rejected");
}

extern "C" void silexNative_NativeResults_native_invalid_utf8(
    SilexNative_NativeResults_native_invalid_utf8Result* output
) {
    output->tag = SilexNative_NativeResults_native_invalid_utf8ResultTag_failure;
    const std::string invalid {static_cast<char>(0xc3), static_cast<char>(0x28)};
    setText(output->failure_bytes, output->failure_length, invalid);
}
