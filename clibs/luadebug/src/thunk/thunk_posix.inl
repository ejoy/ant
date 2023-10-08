#include <sys/mman.h>

#include <cstring>

#include "thunk_jit.h"

bool thunk::create(size_t s) {
    data = mmap(NULL, s, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    if (!data) {
        size = 0;
        return false;
    }
    size = s;
    return true;
}

bool thunk::write(void* buf) {
    memcpy(data, buf, size);
    mprotect(data, size, PROT_READ | PROT_EXEC);
    return true;
}

thunk::~thunk() {
    if (!data) return;
    munmap(data, size);
}
