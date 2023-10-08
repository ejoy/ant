#include <Windows.h>

#include "thunk_jit.h"

bool thunk::create(size_t s) {
    data = VirtualAllocEx(GetCurrentProcess(), NULL, s, MEM_COMMIT, PAGE_EXECUTE_READWRITE);
    if (!data) {
        size = 0;
        return false;
    }
    size = s;
    return true;
}

bool thunk::write(void* buf) {
    SIZE_T written = 0;
    BOOL ok        = WriteProcessMemory(GetCurrentProcess(), data, buf, size, &written);
    if (!ok || written != size) {
        return false;
    }
    return true;
}

thunk::~thunk() {
    if (!data) return;
    VirtualFreeEx(GetCurrentProcess(), data, 0, MEM_RELEASE);
}
