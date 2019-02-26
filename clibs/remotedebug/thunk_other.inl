#include "thunk.h"
#include <lua.hpp>

static int DBG = 0;

static intptr_t get_dbg(lua_State* L) {
    if (LUA_TLIGHTUSERDATA != lua_rawgetp(L, LUA_REGISTRYINDEX, &DBG)) {
        lua_pop(L, 1);
        return 0;
    }
    intptr_t dbg = (intptr_t)lua_touserdata(L, -1);
    lua_pop(L, 1);
    return dbg;
}

static void set_dbg(lua_State* L, intptr_t dbg) {
    lua_pushlightuserdata(L, (void*)dbg);
    lua_rawsetp(L, LUA_REGISTRYINDEX, &DBG);
}

static void (*global_hook)(intptr_t dbg, lua_State* L, lua_Debug* ar);

static void static_hook(lua_State* L, lua_Debug* ar) {
    intptr_t dbg = get_dbg(L);
    if (!dbg) {
        lua_sethook(L, NULL, 0, 0);
        return;
    }
    global_hook(dbg, L, ar);
}

void thunk_bind(intptr_t L, intptr_t dbg) {
    set_dbg((lua_State*)L, dbg);
}

thunk* thunk_create_hook(intptr_t dbg, intptr_t hook) {
    global_hook = (void (*)(intptr_t dbg, lua_State* L, lua_Debug* ar))hook;
    thunk* t = new thunk;
    t->data = (void*)static_hook;
    return t;
}

thunk* thunk_create_panic(intptr_t dbg, intptr_t panic) {
    // TODO
    return 0;
}

thunk* thunk_create_panic(intptr_t dbg, intptr_t panic, intptr_t old_panic) {
    if (!old_panic) {
        return thunk_create_panic(dbg, panic);
    }
    // TODO
    return 0;
}
