#pragma once

#include <queue>
#include <mutex>

namespace ant {
    template <class T>
    class lockqueue {
    public:
        void push(const T& data) {
            std::unique_lock<std::mutex> lk(mutex);
            queue.push(data);
        }
        void push(T&& data) {
            std::unique_lock<std::mutex> lk(mutex);
            queue.push(std::forward<T>(data));
        }
        bool pop(T& data) {
            std::unique_lock<std::mutex> lk(mutex);
            if (queue.empty()) {
                return false;
            }
            data = queue.front();
            queue.pop();
            return true;
        }
    protected:
        std::queue<T> queue;
        std::mutex mutex;
    };
}
