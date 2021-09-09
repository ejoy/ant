#pragma once

#include <lua.hpp>
typedef lua_State* luaref;

luaref luaref_init   (lua_State* L);
void   luaref_close  (luaref refL);
bool   luaref_isvalid(luaref refL, int ref);
int    luaref_ref    (luaref refL, lua_State* L);
void   luaref_unref  (luaref refL, int ref);
void   luaref_get    (luaref refL, lua_State* L, int ref);
