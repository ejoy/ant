#include <memory>

#include "thunk_jit.h"

thunk* thunk_create_hook(intptr_t dbg, intptr_t hook) {
    // int __cedel thunk_hook(lua_State* L, lua_Debug* ar)
    // {
    //     `hook`(`dbg`, L, ar);
    //     return `undefinition`;
    // }
    static unsigned char sc[] = {
        0x57,                                                        // push rdi
        0x50,                                                        // push rax
        0x48, 0x83, 0xec, 0x28,                                      // sub rsp, 0x28
        0x4c, 0x8b, 0xc2,                                            // mov r8, rdx
        0x48, 0x8b, 0xd1,                                            // mov rdx, rcx
        0x48, 0xb9, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,  // mov rcx, dbg
        0x48, 0xb8, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,  // mov rax, hook
        0xff, 0xd0,                                                  // call rax
        0x48, 0x83, 0xc4, 0x28,                                      // add rsp, 0x28
        0x58,                                                        // pop rax
        0x5f,                                                        // pop rdi
        0xc3,                                                        // ret
    };
    std::unique_ptr<thunk> t(new thunk);
    if (!t->create(sizeof(sc))) {
        return 0;
    }
    memcpy(sc + 14, &dbg, sizeof(dbg));
    memcpy(sc + 24, &hook, sizeof(hook));
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
        0x57,                                                        // push rdi
        0x48, 0x83, 0xec, 0x28,                                      // sub rsp, 0x28
        0x48, 0xb9, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,  // mov rcx, dbg
        0x48, 0xb8, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,  // mov rax, hook
        0xff, 0xd0,                                                  // call rax
        0x48, 0x83, 0xc4, 0x28,                                      // add rsp, 0x28
        0x5f,                                                        // pop rdi
        0xc3,                                                        // ret
    };
    std::unique_ptr<thunk> t(new thunk);
    if (!t->create(sizeof(sc))) {
        return 0;
    }
    memcpy(sc + 7, &dbg, sizeof(dbg));
    memcpy(sc + 17, &allocf, sizeof(allocf));
    if (!t->write(&sc)) {
        return 0;
    }
    return t.release();
}
