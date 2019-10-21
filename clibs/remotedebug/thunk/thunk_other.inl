#include "thunk.h"
#include <lua.hpp>
#include "../lua_compat.h"

intptr_t thunk_get(lua_State* L, void* key) {
    if (LUA_TLIGHTUSERDATA != lua::rawgetp(L, LUA_REGISTRYINDEX, key)) {
        lua_pop(L, 1);
        return 0;
    }
    intptr_t v = (intptr_t)lua_touserdata(L, -1);
    lua_pop(L, 1);
    return v;
}

void thunk_set(lua_State* L, void* key, intptr_t v) {
    lua_pushlightuserdata(L, (void*)v);
    lua_rawsetp(L, LUA_REGISTRYINDEX, key);
}

thunk* thunk_create_hook(intptr_t dbg, intptr_t hook) {
    thunk* t = new thunk;
    t->data = (void*)hook;
    return t;
}

thunk* thunk_create_panic(intptr_t dbg, intptr_t panic) {
    thunk* t = new thunk;
    t->data = (void*)panic;
    return t;
}
