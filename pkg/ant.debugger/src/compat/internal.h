#pragma once

#include "compat/lua.h"

#ifdef LUAJIT_VERSION
const char* lua_cdatatype(lua_State* L, int idx);
int lua_isinteger(lua_State* L, int idx);
#endif

const void* lua_tocfunction_pointer(lua_State* L, int idx);

#ifdef LUAJIT_VERSION
union TValue;
struct GCproto;
using CallInfo = TValue;
using Proto    = GCproto;
#else
struct CallInfo;
struct Proto;
#endif

Proto* lua_getproto(lua_State* L, int idx);
CallInfo* lua_getcallinfo(lua_State* L);
Proto* lua_ci2proto(CallInfo* ci);
CallInfo* lua_debug2ci(lua_State* L, const lua_Debug* ar);

#ifdef LUAJIT_VERSION
int lua_isluafunc(lua_State* L, lua_Debug* ar);
#endif

int lua_stacklevel(lua_State* L);
lua_State* lua_getmainthread(lua_State* L);
