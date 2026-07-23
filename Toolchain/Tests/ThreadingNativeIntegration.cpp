#include <atomic>
#include <cassert>
#include <condition_variable>
#include <cstdint>
#include <mutex>
#include <stdexcept>
#include <thread>
#include <vector>
#include <SilexNative/STD.h>

namespace {

struct Observation {
    std::atomic<std::int64_t> calls { 0 };
    std::atomic<bool> workerThread { false };
    std::thread::id ownerThread;
};

struct BlockingObservation {
    std::mutex mutex;
    std::condition_variable changed;
    bool started { false };
    bool released { false };
};

void observe(void* context) {
    auto& observation = *static_cast<Observation*>(context);
    observation.workerThread.store(
        std::this_thread::get_id() != observation.ownerThread,
        std::memory_order_relaxed
    );
    observation.calls.fetch_add(1, std::memory_order_relaxed);
}

void blockUntilReleased(void* context) {
    auto& observation = *static_cast<BlockingObservation*>(context);
    std::unique_lock lock(observation.mutex);
    observation.started = true;
    observation.changed.notify_all();
    observation.changed.wait(lock, [&observation] { return observation.released; });
}

} // namespace

int main() {
    bool rejectedZero = false;
    try {
        silexNative_STD_Threading_native_create_manager(0);
    } catch (const std::invalid_argument&) {
        rejectedZero = true;
    }
    assert(rejectedZero);

    auto* manager = silexNative_STD_Threading_native_create_manager(2);
    std::vector<Observation> observations(8);
    std::vector<SilexNative_STD_Threading_NativeTask*> tasks;
    tasks.reserve(observations.size());
    for (Observation& observation : observations) {
        observation.ownerThread = std::this_thread::get_id();
        tasks.push_back(silexNative_STD_Threading_native_submit(
            manager,
            &observe,
            &observation
        ));
    }

    for (auto* task : tasks) {
        silexNative_STD_Threading_native_complete(task);
        silexNative_STD_Threading_native_complete(task);
    }
    for (const Observation& observation : observations) {
        assert(observation.calls.load(std::memory_order_relaxed) == 1);
        assert(observation.workerThread.load(std::memory_order_relaxed));
    }
    for (auto* task : tasks) {
        silexNative_STD_Threading_native_destroy_task(task);
    }

    BlockingObservation blocking;
    auto* blockingTask = silexNative_STD_Threading_native_submit(
        manager,
        &blockUntilReleased,
        &blocking
    );
    {
        std::unique_lock lock(blocking.mutex);
        blocking.changed.wait(lock, [&blocking] { return blocking.started; });
    }
    std::atomic<bool> destroying { false };
    std::atomic<bool> destroyed { false };
    std::thread destroyer([&] {
        destroying.store(true, std::memory_order_release);
        silexNative_STD_Threading_native_destroy_task(blockingTask);
        destroyed.store(true, std::memory_order_release);
    });
    while (!destroying.load(std::memory_order_acquire)) {
        std::this_thread::yield();
    }
    assert(!destroyed.load(std::memory_order_acquire));
    {
        std::scoped_lock lock(blocking.mutex);
        blocking.released = true;
    }
    blocking.changed.notify_all();
    destroyer.join();
    assert(destroyed.load(std::memory_order_acquire));

    silexNative_STD_Threading_native_destroy_manager(manager);
    return 0;
}
