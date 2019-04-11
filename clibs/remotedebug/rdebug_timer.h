#pragma once

#include <chrono>

namespace remotedebug {
    using namespace std::chrono;
    struct timer {
        time_point<system_clock> last = system_clock::now();
        bool update(int ms) {
            auto now = system_clock::now();
            auto diff = duration_cast<milliseconds>(now - last);
            if (diff.count() > ms) {
                last = now;
                return true;
            }
            return false;
        }
    };
}
