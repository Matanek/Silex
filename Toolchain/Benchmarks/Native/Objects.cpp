#include <cstdint>
#include <cstdio>
#include <memory>
#include <vector>

class Value {
    public: virtual ~Value() = default;
    public: virtual std::int64_t get() const noexcept = 0;
};

class Snapshot final : public Value {
    public: explicit Snapshot(std::int64_t value) noexcept : value(value) {}
    public: std::int64_t get() const noexcept override { return value; }
    private: std::int64_t value { 0 };
};

class Counter {
    public: void add(std::int64_t amount) noexcept { value += amount; }
    public: std::int64_t get() const noexcept { return value; }
    private: std::int64_t value { 0 };
};

template <typename T>
T identity(T value) {
    return value;
}

std::int64_t calculate(std::int64_t iterations) {
    Counter counter;
    const std::vector<std::int64_t> values { 3, 5, 7, 11 };
    std::int64_t index = 0;
    while (index < iterations) {
        if (index % 2 == 0) {
            const std::int64_t count = static_cast<std::int64_t>(values.size());
            counter.add(identity(values[index % count]));
        } else {
            counter.add(1);
        }
        index += 1;
    }
    const std::unique_ptr<Value> result =
        std::make_unique<Snapshot>(counter.get());
    return result->get();
}

int main() {
    std::printf("%lld\n", static_cast<long long>(calculate(2'000'000)));
    return 0;
}
