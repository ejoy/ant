#pragma once

#if defined(__cplusplus)
#include <lua.hpp>
extern "C"
#else
#include <lua.h>
#endif
void ant_loadmodules(lua_State* L);
