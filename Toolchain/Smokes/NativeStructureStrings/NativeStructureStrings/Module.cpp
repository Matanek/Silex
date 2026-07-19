#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <string>
#include <SilexNative/NativeStructureStrings.h>

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

char* copyBytes(const char* bytes, std::int64_t length) {
    if (length == 0) return nullptr;
    auto* copy = static_cast<char*>(std::malloc(static_cast<std::size_t>(length)));
    if (copy != nullptr) std::memcpy(copy, bytes, static_cast<std::size_t>(length));
    trackAllocation(copy);
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

#if defined(__APPLE__)
extern "C" void free(void* pointer) {
    if (pointer == nullptr) return;
    trackFree(pointer);
    malloc_zone_free(malloc_zone_from_ptr(pointer), pointer);
}
#endif

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
