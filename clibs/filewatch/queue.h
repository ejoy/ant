#pragma once

#include <atomic>
#include <mutex>
#include <queue>
#include <thread>

template <typename T>
class blocking_queue
    : protected std::queue<T>
{
public:
    typedef std::queue<T> mybase;
public:
    blocking_queue()
        : mybase()
        , m()
    {
    }
    virtual ~blocking_queue()
    { }
    void push(T&& val) {
        std::unique_lock<spinlock> lock(m);
        mybase::push(val);
    }
    void push(const T& val) {
        std::unique_lock<spinlock> lock(m);
        mybase::push(val);
    }
    bool try_pop(T& val) {
        std::unique_lock<spinlock> lock(m);
        if (mybase::empty()) {
            return false;
        }
        val = mybase::front();
        mybase::pop();
        return true;
    }
protected:
    struct spinlock {
        std::atomic_flag l;
        bool try_lock() {
            return !l.test_and_set(std::memory_order_acquire);
        }
        void lock() {
            for (unsigned n = 0; !try_lock(); ++n) {
                yield(n);
            }
        }
        void unlock() {
            l.clear(std::memory_order_release);
        }
        void yield(unsigned n) {
            if (n >= 16) {
                std::this_thread::yield();
            }
        }
    };
    spinlock m;
private:
    blocking_queue(const blocking_queue&);
    blocking_queue& operator=(const blocking_queue&);
};
