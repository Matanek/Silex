#include <cstdint>
#include <random>

extern "C" std::int64_t silexNative_std_Random_native_seed() {
    std::random_device source;
    return static_cast<std::int64_t>(source());
}
