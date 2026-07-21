#include <cstdlib>
#include <string>
#include <vector>

namespace {
std::vector<std::string> runtimeArguments;
}

extern "C" std::int64_t silexRuntimeArgumentCount() {
    return static_cast<std::int64_t>(runtimeArguments.size());
}

extern "C" const char* silexRuntimeArgumentValue(
    std::int64_t index,
    std::int64_t* length
) {
    const auto& value = runtimeArguments[static_cast<std::size_t>(index)];
    *length = static_cast<std::int64_t>(value.size());
    return value.data();
}

#define SILEX_PROCESS_SIMULATE_EXECUTABLE_UNAVAILABLE 1
#include "../../Library/STD/@Native/Process.cpp"

namespace {

void countArguments(void* context, std::int64_t first, std::int64_t) {
    if (first == 1) ++*static_cast<int*>(context);
}

void release(SilexProcessOperationResult& result) {
    std::free(result.detailBytes);
}

void release(SilexProcessPathResult& result) {
    std::free(result.pathBytes);
    std::free(result.detailBytes);
}

} // namespace

int main() {
    runtimeArguments = {"program", "", "été"};
    int count = 0;
    SilexProcessOperationResult valid{};
    silexNative_STD_Process_native_visit_arguments(countArguments, &count, &valid);
    if (!valid.succeeded || count != 3) return 2;
    release(valid);

    runtimeArguments = {"program", std::string(1, static_cast<char>(0xff))};
    SilexProcessOperationResult invalid{};
    silexNative_STD_Process_native_visit_arguments(countArguments, &count, &invalid);
    if (invalid.succeeded || invalid.errorKind != 4) return 3;
    release(invalid);

    SilexProcessPathResult unavailable{};
    silexNative_STD_Process_native_executable_path(&unavailable);
    if (unavailable.succeeded || unavailable.errorKind != 29) return 4;
    release(unavailable);

    return silexNative_STD_Process_native_id() == 0 ? 5 : 0;
}
