#include <memory.h>

#include <memory>

#include "thunk_jit.h"

thunk* thunk_create_hook(intptr_t dbg, intptr_t hook) {
    // int __cedel thunk_hook(lua_State* L, lua_Debug* ar)
    // {
    //     `hook`(`dbg`, L, ar);
    //     return `undefinition`;
    // }
    static unsigned char sc[] = {
        0x50,                                                        // push rax
        0x48, 0x89, 0xf2,                                            // mov rdx, rsi
        0x48, 0x89, 0xfe,                                            // mov rsi, rdi
        0x48, 0xbf, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,  // mov rdi, dbg
        0x48, 0xb8, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,  // mov rax, hook
        0xff, 0xd0,                                                  // call rax
        0x58,                                                        // pop rax
        0xc3,                                                        // ret
    };
    std::unique_ptr<thunk> t(new thunk);
    if (!t->create(sizeof(sc))) {
        return 0;
    }
    memcpy(sc + 9, &dbg, sizeof(dbg));
    memcpy(sc + 19, &hook, sizeof(hook));
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
        0x48, 0xbf, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,  // mov rdi, dbg
        0x48, 0xb8, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,  // mov rax, hook
        0xff, 0xd0,                                                  // call rax
        0xc3,                                                        // ret
    };
    std::unique_ptr<thunk> t(new thunk);
    if (!t->create(sizeof(sc))) {
        return 0;
    }
    memcpy(sc + 2, &dbg, sizeof(dbg));
    memcpy(sc + 12, &allocf, sizeof(allocf));
    if (!t->write(&sc)) {
        return 0;
    }
    return t.release();
}
