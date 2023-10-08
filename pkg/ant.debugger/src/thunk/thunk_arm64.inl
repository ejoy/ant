#include <memory.h>

#include <memory>

#include "thunk_jit.h"

#pragma pack(1)
struct thunkblock_arg2 {
    unsigned int mov_x2_x1;
    unsigned int mov_x1_x0;
    unsigned int ldr_x0_0x0c;
    unsigned int ldr_x3_0x10;
    unsigned int br_x3;
    intptr_t arg0;
    intptr_t realfn;
};
struct thunkblock_arg3 {
    unsigned int ldr_x0_0x0c;
    unsigned int ldr_x4_0x10;
    unsigned int br_x4;
    intptr_t arg0;
    intptr_t realfn;
};
#pragma pack()

thunk *thunk_create_hook(intptr_t dbg, intptr_t hook) {
    // int __cedel thunk_hook(lua_State* L, lua_Debug* ar)
    // {
    //     `hook`(`dbg`, L, ar);
    //     return `undefinition`;
    // }

    std::unique_ptr<thunk> t(new thunk);
    if (!t->create(sizeof(thunkblock_arg2))) {
        return 0;
    }

    thunkblock_arg2 thunkblock;
    thunkblock.mov_x2_x1   = 0xAA0103E2;  // mov x2,x1
    thunkblock.mov_x1_x0   = 0xAA0003E1;  // mov x1,x0
    thunkblock.ldr_x0_0x0c = 0x58000060;  // ldr x0,#0xc
    thunkblock.ldr_x3_0x10 = 0x58000083;  // ldr x3,#0x10
    thunkblock.br_x3       = 0xD61F0060;  // br x3
    thunkblock.arg0        = dbg;
    thunkblock.realfn      = hook;

    if (!t->write(&thunkblock)) {
        return 0;
    }
    return t.release();
}

thunk *thunk_create_allocf(intptr_t dbg, intptr_t allocf) {
    // void* __cedel thunk_allocf(void *ud, void *ptr, size_t osize, size_t nsize)
    // {
    //     return `allocf`(`dbg`, ptr, osize, nsize);
    // }
    thunkblock_arg3 thunkblock;
    thunkblock.ldr_x0_0x0c = 0x58000060;  // ldr x0,#0xc
    thunkblock.ldr_x4_0x10 = 0x58000084;  // ldr x4,#0x10
    thunkblock.br_x4       = 0xD61F0080;  // br x3
    thunkblock.arg0        = dbg;
    thunkblock.realfn      = allocf;

    std::unique_ptr<thunk> t(new thunk);
    if (!t->create(sizeof(thunkblock_arg3))) {
        return 0;
    }
    if (!t->write(&thunkblock)) {
        return 0;
    }
    return t.release();
}
