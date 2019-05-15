#include "thunk.h"
#include <lua.hpp>

static int HOOK = 0;
static int PANIC = 0;
static lua_State* GL = 0;

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
    GL = (lua_State*)L;
}

static void static_hook(lua_State* L, lua_Debug* ar) {
    thunk* t = (thunk*)get(L, &HOOK);
    if (!t) {
        lua_sethook(L, NULL, 0, 0);
        return;
    }
    ((void (*)(intptr_t dbg, lua_State* L, lua_Debug* ar))t->func1)(t->dbg, L, ar);
}

thunk* thunk_create_hook(intptr_t dbg, intptr_t hook) {
    thunk* t = new thunk;
    t->data = (void*)static_hook;
    t->dbg = dbg;
    t->func1 = hook;
    set(GL, &HOOK, (intptr_t)t);
    return t;
}

static int static_panic_1(lua_State* L) {
    thunk* t = (thunk*)get(L, &PANIC);
    if (!t) {
        return 0;
    }
    ((void (*)(intptr_t dbg, lua_State* L))t->func1)(t->dbg, L);
    return 0;
}

static int static_panic_2(lua_State* L) {
    thunk* t = (thunk*)get(L, &PANIC);
    if (!t) {
        return 0;
    }
    ((void (*)(intptr_t dbg, lua_State* L))t->func1)(t->dbg, L);
    return ((int (*)(lua_State* L))t->func2)(L);
}

thunk* thunk_create_panic(intptr_t dbg, intptr_t panic) {
    thunk* t = new thunk;
    t->data = (void*)static_panic_1;
    t->dbg = dbg;
    t->func1 = panic;
    set(GL, &PANIC, (intptr_t)t);
    return t;
}

thunk* thunk_create_panic(intptr_t dbg, intptr_t panic, intptr_t old_panic) {
    if (!old_panic) {
        return thunk_create_panic(dbg, panic);
    }
    thunk* t = new thunk;
    t->data = (void*)static_panic_2;
    t->dbg = dbg;
    t->func1 = panic;
    t->func2 = old_panic;
    set(GL, &PANIC, (intptr_t)t);
    return t;
}
