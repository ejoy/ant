#pragma once

#include <mutex>
#include <condition_variable>

namespace ant {
    class semaphore {
    public:
        void signal() {
            std::unique_lock<std::mutex> lk(mutex);
            if (ok) {
                return;
            }
            ok = true;
            lk.unlock();
            condition.notify_one();
        }
        void wait() {
            std::unique_lock<std::mutex> lk(mutex);
            condition.wait(lk, [this] { return ok; });
            ok = false;
        }
        bool timed_wait(int timeout) {
            std::unique_lock<std::mutex> lk(mutex);
            if (timeout < 0) {
                condition.wait(lk, [this] { return ok; });
                ok = false;
                return true;
            }
            if (condition.wait_for(lk, std::chrono::milliseconds(timeout), [this] { return ok; })) {
                ok = false;
                return true;
            }
            return false;
        }
    private:
        std::mutex mutex;
        std::condition_variable condition;
        bool ok = false;
    };
}
