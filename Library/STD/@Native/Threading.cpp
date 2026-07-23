#include <condition_variable>
#include <cstdint>
#include <deque>
#include <exception>
#include <memory>
#include <mutex>
#include <stdexcept>
#include <thread>
#include <utility>
#include <vector>
#include <SilexNative/STD.h>

namespace {

struct TaskState {
    void (*callback)(void*) { nullptr };
    void* (*resultCallback)(void*) { nullptr };
    void* context { nullptr };
    void* result { nullptr };
    void (*destroyResult)(void*) { nullptr };
    std::exception_ptr failure;
    std::mutex mutex;
    std::condition_variable completion;
    bool complete { false };
};

void completeTask(const std::shared_ptr<TaskState>& task) {
    void* result = nullptr;
    std::exception_ptr failure;
    try {
        if (task->resultCallback != nullptr) {
            result = task->resultCallback(task->context);
        } else {
            task->callback(task->context);
        }
    } catch (...) {
        failure = std::current_exception();
    }
    {
        std::scoped_lock lock(task->mutex);
        task->result = result;
        task->failure = failure;
        task->complete = true;
    }
    task->completion.notify_all();
}

} // namespace

struct SilexNative_STD_Threading_NativeTaskManager {
    std::mutex mutex;
    std::condition_variable available;
    std::deque<std::shared_ptr<TaskState>> pending;
    std::vector<std::thread> workers;
    bool stopping { false };
};

struct SilexNative_STD_Threading_NativeTask {
    std::shared_ptr<TaskState> state;
};

namespace {

void workerLoop(SilexNative_STD_Threading_NativeTaskManager* manager) {
    while (true) {
        std::shared_ptr<TaskState> task;
        {
            std::unique_lock lock(manager->mutex);
            manager->available.wait(lock, [manager] {
                return manager->stopping || !manager->pending.empty();
            });
            if (manager->pending.empty()) {
                if (manager->stopping) return;
                continue;
            }
            task = std::move(manager->pending.front());
            manager->pending.pop_front();
        }
        completeTask(task);
    }
}

void waitForTask(const std::shared_ptr<TaskState>& task) {
    std::unique_lock lock(task->mutex);
    task->completion.wait(lock, [&task] { return task->complete; });
}

void rethrowTaskFailure(const std::shared_ptr<TaskState>& task) {
    std::exception_ptr failure;
    {
        std::scoped_lock lock(task->mutex);
        failure = task->failure;
    }
    if (failure != nullptr) std::rethrow_exception(failure);
}

SilexNative_STD_Threading_NativeTask* enqueueTask(
    SilexNative_STD_Threading_NativeTaskManager* manager,
    std::shared_ptr<TaskState> state
) {
    auto task = std::make_unique<SilexNative_STD_Threading_NativeTask>();
    task->state = state;
    {
        std::scoped_lock lock(manager->mutex);
        if (manager->stopping) throw std::runtime_error("TaskManager is stopping");
        manager->pending.push_back(std::move(state));
    }
    manager->available.notify_one();
    return task.release();
}

} // namespace

extern "C" std::int64_t silexNative_STD_Threading_native_logical_processor_count() {
    return static_cast<std::int64_t>(std::thread::hardware_concurrency());
}

extern "C" SilexNative_STD_Threading_NativeTaskManager*
silexNative_STD_Threading_native_create_manager(std::int64_t workerCount) {
    if (workerCount <= 0) throw std::invalid_argument("worker count must be positive");
    auto manager = std::make_unique<SilexNative_STD_Threading_NativeTaskManager>();
    manager->workers.reserve(static_cast<std::size_t>(workerCount));
    try {
        for (std::int64_t index = 0; index < workerCount; ++index) {
            manager->workers.emplace_back(workerLoop, manager.get());
        }
    } catch (...) {
        {
            std::scoped_lock lock(manager->mutex);
            manager->stopping = true;
        }
        manager->available.notify_all();
        for (std::thread& worker : manager->workers) {
            if (worker.joinable()) worker.join();
        }
        throw;
    }
    return manager.release();
}

extern "C" SilexNative_STD_Threading_NativeTask*
silexNative_STD_Threading_native_submit(
    const SilexNative_STD_Threading_NativeTaskManager* borrowedManager,
    void (*callback)(void*),
    void* callbackContext
) {
    auto* manager = const_cast<SilexNative_STD_Threading_NativeTaskManager*>(borrowedManager);
    auto state = std::make_shared<TaskState>();
    state->callback = callback;
    state->context = callbackContext;
    return enqueueTask(manager, std::move(state));
}

extern "C" SilexNative_STD_Threading_NativeTask*
silexNative_STD_Threading_native_submit_result(
    const SilexNative_STD_Threading_NativeTaskManager* borrowedManager,
    void* (*callback)(void*),
    void* callbackContext,
    void (*destroyResult)(void*)
) {
    auto* manager = const_cast<SilexNative_STD_Threading_NativeTaskManager*>(borrowedManager);
    auto state = std::make_shared<TaskState>();
    state->resultCallback = callback;
    state->context = callbackContext;
    state->destroyResult = destroyResult;
    return enqueueTask(manager, std::move(state));
}

extern "C" void silexNative_STD_Threading_native_complete(
    const SilexNative_STD_Threading_NativeTask* task
) {
    waitForTask(task->state);
    rethrowTaskFailure(task->state);
}

extern "C" void silexNative_STD_Threading_native_complete_result(
    const SilexNative_STD_Threading_NativeTask* task,
    void (*callback)(void*, void*),
    void* callbackContext
) {
    waitForTask(task->state);
    rethrowTaskFailure(task->state);

    void* result = nullptr;
    void (*destroyResult)(void*) = nullptr;
    {
        std::scoped_lock lock(task->state->mutex);
        result = std::exchange(task->state->result, nullptr);
        destroyResult = std::exchange(task->state->destroyResult, nullptr);
    }
    if (result == nullptr || destroyResult == nullptr) {
        throw std::logic_error("completed task result was already consumed");
    }
    std::unique_ptr<void, void (*)(void*)> resultGuard(result, destroyResult);
    callback(callbackContext, result);
}

extern "C" void silexNative_STD_Threading_native_destroy_task(
    SilexNative_STD_Threading_NativeTask* task
) {
    waitForTask(task->state);
    void* result = nullptr;
    void (*destroyResult)(void*) = nullptr;
    {
        std::scoped_lock lock(task->state->mutex);
        result = std::exchange(task->state->result, nullptr);
        destroyResult = std::exchange(task->state->destroyResult, nullptr);
    }
    if (result != nullptr && destroyResult != nullptr) destroyResult(result);
    delete task;
}

extern "C" void silexNative_STD_Threading_native_destroy_manager(
    SilexNative_STD_Threading_NativeTaskManager* manager
) {
    {
        std::scoped_lock lock(manager->mutex);
        manager->stopping = true;
    }
    manager->available.notify_all();
    for (std::thread& worker : manager->workers) {
        if (worker.joinable()) worker.join();
    }
    delete manager;
}
