#include <atomic>
#include <cstdint>
#include <thread>
#include <SilexNative/NativeIsolatedCallbacks.h>

struct SilexNative_NativeIsolatedCallbacks_Operation {
    void (*callback)(void*);
    void* context;
    std::thread::id ownerThread;
    std::thread worker;
};

namespace {

std::atomic<std::int64_t> invocationCount { 0 };
std::atomic<std::int64_t> destroyedCount { 0 };
std::atomic<std::int64_t> liveWorkerCount { 0 };
std::atomic<bool> ranOnWorker { false };

} // namespace

extern "C" SilexNative_NativeIsolatedCallbacks_Operation*
silexNative_NativeIsolatedCallbacks_start_operation(
    void (*callback)(void*),
    void* callbackContext
) {
    auto* operation = new SilexNative_NativeIsolatedCallbacks_Operation;
    operation->callback = callback;
    operation->context = callbackContext;
    operation->ownerThread = std::this_thread::get_id();
    operation->worker = std::thread([operation]() {
        liveWorkerCount.fetch_add(1, std::memory_order_relaxed);
        ranOnWorker.store(
            std::this_thread::get_id() != operation->ownerThread,
            std::memory_order_relaxed
        );
        operation->callback(operation->context);
        invocationCount.fetch_add(1, std::memory_order_relaxed);
        liveWorkerCount.fetch_sub(1, std::memory_order_relaxed);
    });
    return operation;
}

extern "C" void silexNative_NativeIsolatedCallbacks_discard_operation(
    SilexNative_NativeIsolatedCallbacks_Operation* operation
) {
    if (operation->worker.joinable()) operation->worker.join();
    delete operation;
    destroyedCount.fetch_add(1, std::memory_order_relaxed);
}

extern "C" void silexNative_NativeIsolatedCallbacks_reset_observations() {
    invocationCount.store(0, std::memory_order_relaxed);
    destroyedCount.store(0, std::memory_order_relaxed);
    liveWorkerCount.store(0, std::memory_order_relaxed);
    ranOnWorker.store(false, std::memory_order_relaxed);
}

extern "C" std::int64_t silexNative_NativeIsolatedCallbacks_invocation_count() {
    return invocationCount.load(std::memory_order_relaxed);
}

extern "C" std::int64_t silexNative_NativeIsolatedCallbacks_destroyed_count() {
    return destroyedCount.load(std::memory_order_relaxed);
}

extern "C" bool silexNative_NativeIsolatedCallbacks_ran_on_worker() {
    return ranOnWorker.load(std::memory_order_relaxed);
}

extern "C" std::int64_t silexNative_NativeIsolatedCallbacks_live_worker_count() {
    return liveWorkerCount.load(std::memory_order_relaxed);
}
