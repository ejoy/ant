#pragma once

#include <mutex>
#include <vector>
#include <bee/thread/spinlock.h>

#if defined(__APPLE__)
typedef void(^SelectHandler)(void* data);
#else
#include <functional>
using SelectHandler = std::function<void(void*)>;
#endif

class MessageChannel {
public:
    void push(void* data) {
        std::unique_lock<bee::spinlock> lk(mutex);
        queue.push_back(data);
    }
    void select(SelectHandler handler) {
        std::unique_lock<bee::spinlock> lk(mutex);
        if (queue.empty()) {
            return;
        }
        for (void* data: queue) {
            handler(data);
        }
        queue.clear();
    }
private:
    std::vector<void*> queue;
    bee::spinlock mutex;
};
