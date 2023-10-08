#pragma once

#include <stddef.h>

struct thunk {
    void* data  = 0;
    size_t size = 0;
    bool create(size_t s);
    bool write(void* buf);
    ~thunk();
};
