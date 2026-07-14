#include <cstdint>
#include <limits>
#include <random>

static std::int64_t toPositive(std::uint64_t value) {
    const auto maximum = static_cast<std::uint64_t>(
        std::numeric_limits<std::int64_t>::max()
    );
    value &= maximum;
    return static_cast<std::int64_t>(value == 0 ? 1 : value);
}

extern "C" std::int64_t silexNative_std_Random_native_next(std::int64_t state) {
    auto value = static_cast<std::uint64_t>(state);
    if (value == 0) value = 0x9E3779B97F4A7C15ULL;
    value ^= value << 13;
    value ^= value >> 7;
    value ^= value << 17;
    return toPositive(value);
}

extern "C" std::int64_t silexNative_std_Random_native_seed() {
    std::random_device source;
    return silexNative_std_Random_native_next(static_cast<std::int64_t>(source()));
}
