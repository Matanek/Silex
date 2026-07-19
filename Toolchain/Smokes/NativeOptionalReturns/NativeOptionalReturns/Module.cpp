#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <string>
#include <SilexNative/NativeOptionalReturns.h>

#if defined(__APPLE__)
#include <malloc/malloc.h>
#endif

namespace {

// -----------------------------------------------------------------------------

struct TrackedAllocation {
    void* pointer { nullptr };
    int frees { 0 };
};

TrackedAllocation trackedAllocations[32];
std::size_t trackedAllocationCount = 0;
bool trackerRegistered = false;

void verifyTrackedAllocations() {
    for (std::size_t index = 0; index < trackedAllocationCount; index += 1) {
        if (trackedAllocations[index].frees != 1) std::_Exit(2);
    }
}

void trackAllocation(void* pointer) {
    if (pointer == nullptr) return;
    if (!trackerRegistered) {
        std::atexit(verifyTrackedAllocations);
        trackerRegistered = true;
    }
    trackedAllocations[trackedAllocationCount++] = {pointer, 0};
}

void trackFree(void* pointer) {
    for (std::size_t index = trackedAllocationCount; index > 0; index -= 1) {
        auto& allocation = trackedAllocations[index - 1];
        if (allocation.pointer != pointer || allocation.frees != 0) continue;
        allocation.frees += 1;
        return;
    }
}

// -----------------------------------------------------------------------------

char* copyText(const std::string& text) {
    if (text.empty()) return nullptr;
    auto* bytes = static_cast<char*>(std::malloc(text.size()));
    if (bytes != nullptr) std::memcpy(bytes, text.data(), text.size());
    trackAllocation(bytes);
    return bytes;
}

void setText(char*& outputBytes, std::int64_t& outputLength, const std::string& text) {
    outputBytes = copyText(text);
    outputLength = static_cast<std::int64_t>(text.size());
}

// -----------------------------------------------------------------------------

} // namespace

#if defined(__APPLE__)
extern "C" void free(void* pointer) {
    if (pointer == nullptr) return;
    trackFree(pointer);
    malloc_zone_free(malloc_zone_from_ptr(pointer), pointer);
}
#endif

extern "C" bool silexNative_NativeOptionalReturns_native_integer(
    std::int64_t value,
    std::int64_t* output
) {
    if (value < 0) return false;
    *output = value;
    return true;
}

extern "C" bool silexNative_NativeOptionalReturns_native_text(
    std::int64_t sequence,
    char** outputBytes,
    std::int64_t* outputLength
) {
    if (sequence % 2 == 0) return false;
    setText(*outputBytes, *outputLength, "texte " + std::to_string(sequence));
    return true;
}

extern "C" bool silexNative_NativeOptionalReturns_native_event(
    std::int64_t sequence,
    SilexNative_NativeOptionalReturns_NativeEvent* output
) {
    if (sequence % 2 == 0) return false;
    output->sequence = sequence;
    setText(output->text_bytes, output->text_length, "événement " + std::to_string(sequence));
    return true;
}

extern "C" bool silexNative_NativeOptionalReturns_native_absent_text_with_buffer(
    char** outputBytes,
    std::int64_t* outputLength
) {
    setText(*outputBytes, *outputLength, "invalid absence");
    return false;
}

extern "C" bool silexNative_NativeOptionalReturns_native_absent_event_with_buffer(
    SilexNative_NativeOptionalReturns_NativeEvent* output
) {
    setText(output->text_bytes, output->text_length, "invalid absence");
    return false;
}
