#include <cstdint>
#include <cstdio>

std::int64_t calculate(std::int64_t limit) {
    std::int64_t total = 0;
    std::int64_t index = 0;
    while (index < limit) {
        total += (index % 97) * 3;
        index += 1;
    }
    return total;
}

int main() {
    std::printf("%lld\n", static_cast<long long>(calculate(1'000'000)));
    return 0;
}
