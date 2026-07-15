#include <chrono>
#include <cstdint>
#include <random>

extern "C" std::int64_t silexNative_STD_Random_native_seed() {
    std::random_device source;
    return static_cast<std::int64_t>(source());
}

extern "C" std::int64_t silexNative_STD_Time_native_monotonic_microseconds() {
    const auto elapsed = std::chrono::steady_clock::now().time_since_epoch();
    return static_cast<std::int64_t>(
        std::chrono::duration_cast<std::chrono::microseconds>(elapsed).count()
    );
}
