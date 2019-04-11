#include "thunk.h"
#include <lua.hpp>

static int DBG = 0;
static int PARAM1 = 0;
static int PARAM2 = 0;

static intptr_t get(lua_State* L, void* key) {
    if (LUA_TLIGHTUSERDATA != lua_rawgetp(L, LUA_REGISTRYINDEX, key)) {
        lua_pop(L, 1);
        return 0;
    }
    intptr_t v = (intptr_t)lua_touserdata(L, -1);
    lua_pop(L, 1);
    return v;
}

static void set(lua_State* L, void* key, intptr_t v) {
    lua_pushlightuserdata(L, (void*)v);
    lua_rawsetp(L, LUA_REGISTRYINDEX, key);
}

void thunk_bind(intptr_t L, intptr_t dbg) {
    set(L, &DBG, dbg);
}

static void static_hook(lua_State* L, lua_Debug* ar) {
    intptr_t dbg = get(L, &DBG);
    if (!dbg) {
        lua_sethook(L, NULL, 0, 0);
        return;
    }
    intptr_t hook = get(L, &PARAM1);
    if (hook) {
       ((void (*)(intptr_t dbg, lua_State* L, lua_Debug* ar))hook)(dbg, L, ar);
    }
}

thunk* thunk_create_hook(intptr_t dbg, intptr_t hook) {
    set(L, &PARAM1, hook);
    thunk* t = new thunk;
    t->data = (void*)static_hook;
    return t;
}

static int static_panic_1(lua_State* L) {
    intptr_t dbg = get(L, &DBG);
    if (!dbg) {
        return 0;
    }
    intptr_t panic = get(L, &PARAM1);
    if (panic) {
        ((void (*)(intptr_t dbg, lua_State* L))panic)(dbg, L);
    }
    return 0;
}

static int static_panic_2(lua_State* L) {
    intptr_t dbg = get(L, &DBG);
    if (!dbg) {
        return 0;
    }
    intptr_t panic = get(L, &PARAM1);
    if (panic) {
        ((void (*)(intptr_t dbg, lua_State* L))panic)(dbg, L);
    }
    intptr_t old_panic = get(L, &PARAM2);
    if (!old_panic) {
        return 0;
    }
    return ((int (*)(lua_State* L))old_panic)(L);
}

thunk* thunk_create_panic(intptr_t dbg, intptr_t panic) {
    set(L, &PARAM1, panic);
    thunk* t = new thunk;
    t->data = (void*)static_panic_1;
    return t;
}

thunk* thunk_create_panic(intptr_t dbg, intptr_t panic, intptr_t old_panic) {
    if (!old_panic) {
        return thunk_create_panic(dbg, panic);
    }
    set(L, &PARAM1, panic);
    set(L, &PARAM2, old_panic);
    thunk* t = new thunk;
    t->data = (void*)static_panic_2;
    return t;
}
