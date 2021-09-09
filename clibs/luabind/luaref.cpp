#include "luaref.h"
#include <assert.h>

#define FREELIST 1

static_assert(LUA_NOREF < FREELIST);

luaref luaref_init(lua_State* L) {
    lua_State* refL = lua_newthread(L);
    lua_rawsetp(L, LUA_REGISTRYINDEX, refL);
    lua_newtable(refL);
    return refL;
}

void luaref_close(luaref refL) {
    lua_State* L = (lua_State*)refL;
    lua_pushnil(L);
    lua_rawsetp(L, LUA_REGISTRYINDEX, refL);
}

bool luaref_isvalid(luaref refL, int ref) {
    if (ref <= FREELIST || ref > lua_gettop(refL)) {
        return false;
    }
    lua_pushnil(refL);
    while (lua_next(refL, FREELIST)) {
        lua_pop(refL, 1);
        if (lua_tointeger(refL, -1) == ref) {
            lua_pop(refL, 1);
            return false;
        }
    }
    return true;
}

int luaref_ref(luaref refL, lua_State* L) {
    if (!lua_checkstack(refL, 3)) {
        return LUA_NOREF;
    }
    lua_xmove(L, refL, 1);
    lua_pushnil(refL);
    if (!lua_next(refL, FREELIST)) {
        return lua_gettop(refL);
    }
    int r = (int)lua_tointeger(refL, -2);
    lua_pop(refL, 1);
    lua_pushnil(refL);
    lua_rawset(refL, FREELIST);
    lua_replace(refL, r);
    return r;
}

void luaref_unref(luaref refL, int ref) {
    if (ref <= FREELIST) {
        return;
    }
    int top = lua_gettop(refL);
    if (ref > top) {
        return;
    }
    if (ref < top) {
        lua_pushboolean(refL, 1);
        lua_rawseti(refL, FREELIST, ref);
        lua_pushnil(refL);
        lua_replace(refL, ref);
        return;
    }
    for (--top; top > FREELIST;--top) {
        if (LUA_TNIL == lua_rawgeti(refL, FREELIST, top)) {
            lua_pop(refL, 1);
            break;
        }
        lua_pop(refL, 1);
        lua_pushnil(refL);
        lua_rawseti(refL, FREELIST, top);
    }
    lua_settop(refL, top);
}

void luaref_get(luaref refL, lua_State* L, int ref) {
    assert(luaref_isvalid(refL, ref));
    lua_pushvalue(refL, ref);
    lua_xmove(refL, L, 1);
}
