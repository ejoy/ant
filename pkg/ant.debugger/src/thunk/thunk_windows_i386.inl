#include <memory>

#include "thunk_jit.h"

thunk* thunk_create_hook(intptr_t dbg, intptr_t hook) {
    // int __cedel thunk_hook(lua_State* L, lua_Debug* ar)
    // {
    //     `hook`(`dbg`, L, ar);
    //     return `undefinition`;
    // }
    static unsigned char sc[] = {
        0xff, 0x74, 0x24, 0x08,        // push [esp+8]
        0xff, 0x74, 0x24, 0x08,        // push [esp+8]
        0x68, 0x00, 0x00, 0x00, 0x00,  // push dbg
        0xe8, 0x00, 0x00, 0x00, 0x00,  // call hook
        0x83, 0xc4, 0x0c,              // add esp, 12
        0xc3,                          // ret
    };
    std::unique_ptr<thunk> t(new thunk);
    if (!t->create(sizeof(sc))) {
        return 0;
    }
    memcpy(sc + 9, &dbg, sizeof(dbg));
    hook = hook - ((intptr_t)t->data + 18);
    memcpy(sc + 14, &hook, sizeof(hook));
    if (!t->write(&sc)) {
        return 0;
    }
    return t.release();
}

thunk* thunk_create_allocf(intptr_t dbg, intptr_t allocf) {
    // void* __cedel thunk_allocf(void *ud, void *ptr, size_t osize, size_t nsize)
    // {
    //     return `allocf`(`dbg`, ptr, osize, nsize);
    // }
    static unsigned char sc[] = {
        0xff, 0x74, 0x24, 0x10,        // push [esp+0x10]
        0xff, 0x74, 0x24, 0x10,        // push [esp+0x10]
        0xff, 0x74, 0x24, 0x10,        // push [esp+0x10]
        0x68, 0x00, 0x00, 0x00, 0x00,  // push dbg
        0xe8, 0x00, 0x00, 0x00, 0x00,  // call allocf
        0x83, 0xc4, 0x10,              // add esp, 0x10
        0xc3,                          // ret
    };
    std::unique_ptr<thunk> t(new thunk);
    if (!t->create(sizeof(sc))) {
        return 0;
    }
    memcpy(sc + 13, &dbg, sizeof(dbg));
    allocf = allocf - ((intptr_t)t->data + 22);
    memcpy(sc + 18, &allocf, sizeof(allocf));
    if (!t->write(&sc)) {
        return 0;
    }
    return t.release();
}
