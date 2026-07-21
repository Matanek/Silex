#include <cstdlib>
#include <cstring>
#include <string>

#include "../../Library/STD/@Native/Environment.cpp"

namespace {

void ignoreValue(void*, std::int64_t, std::int64_t) {}

void release(SilexEnvironmentLookupResult& result) {
    std::free(result.valueBytes);
    std::free(result.detailBytes);
}

void release(SilexEnvironmentOperationResult& result) {
    std::free(result.detailBytes);
}

} // namespace

int main() {
    const std::string name = "SILEX_ENVIRONMENT_NATIVE_INTEGRATION_4D2C";
    const std::string first = "first";
    const std::string second = "second";

    SilexEnvironmentOperationResult removed{};
    silexNative_STD_Environment_native_remove(
        name.data(), static_cast<std::int64_t>(name.size()), &removed
    );
    if (!removed.succeeded) return 2;
    release(removed);

    SilexEnvironmentLookupResult absent{};
    silexNative_STD_Environment_native_get(
        name.data(), static_cast<std::int64_t>(name.size()), &absent
    );
    if (!absent.succeeded || absent.present) return 3;
    release(absent);

    SilexEnvironmentOperationResult set{};
    silexNative_STD_Environment_native_set(
        name.data(), static_cast<std::int64_t>(name.size()),
        first.data(), static_cast<std::int64_t>(first.size()), &set
    );
    if (!set.succeeded) return 4;
    release(set);

    SilexEnvironmentLookupResult copied{};
    silexNative_STD_Environment_native_get(
        name.data(), static_cast<std::int64_t>(name.size()), &copied
    );
    if (!copied.succeeded || !copied.present || copied.valueLength != 5 ||
        std::memcmp(copied.valueBytes, first.data(), first.size()) != 0) return 5;

    SilexEnvironmentOperationResult replaced{};
    silexNative_STD_Environment_native_set(
        name.data(), static_cast<std::int64_t>(name.size()),
        second.data(), static_cast<std::int64_t>(second.size()), &replaced
    );
    if (!replaced.succeeded ||
        std::memcmp(copied.valueBytes, first.data(), first.size()) != 0) return 6;
    release(replaced);
    release(copied);

    SilexEnvironmentOperationResult invalidName{};
    silexNative_STD_Environment_native_set("", 0, first.data(), 5, &invalidName);
    if (invalidName.succeeded || invalidName.errorKind != 3) return 7;
    release(invalidName);

#if !defined(_WIN32)
    const std::string invalidNameBytes = "SILEX_ENVIRONMENT_INVALID_UTF8_4D2C";
    const char invalidValue[] = {static_cast<char>(0xff), '\0'};
    if (::setenv(invalidNameBytes.c_str(), invalidValue, 1) != 0) return 8;
    SilexEnvironmentOperationResult invalidVariables{};
    silexNative_STD_Environment_native_visit_variables(
        ignoreValue, nullptr, &invalidVariables
    );
    ::unsetenv(invalidNameBytes.c_str());
    if (invalidVariables.succeeded || invalidVariables.errorKind != 4) return 9;
    release(invalidVariables);
#endif

    SilexEnvironmentOperationResult cleanup{};
    silexNative_STD_Environment_native_remove(
        name.data(), static_cast<std::int64_t>(name.size()), &cleanup
    );
    const bool succeeded = cleanup.succeeded;
    release(cleanup);
    return succeeded ? 0 : 10;
}
