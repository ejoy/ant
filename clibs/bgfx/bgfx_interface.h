#ifndef lua_bgfx_interface_h
#define lua_bgfx_interface_h

#include <lua.h>
#include <lauxlib.h>
#include <bgfx/c99/bgfx.h>

static bgfx_interface_vtbl_t* bgfx_inf_ = 0;

static inline void
init_interface(lua_State* L) {
	if (bgfx_inf_) {
		return;
	}
#ifdef BGFX_STATIC_LINK
	bgfx_interface_vtbl_t* inf = bgfx_get_interface(BGFX_API_VERSION);
	if (inf == NULL) {
		luaL_error(L, "BGFX_API_VERSION (%d) mismatch.", BGFX_API_VERSION);
		return;
	}
	bgfx_inf_ = inf;
	lua_pushcfunction(L, (lua_CFunction)bgfx_get_interface);
	lua_setfield(L, LUA_REGISTRYINDEX, "BGFX_GET_INTERFACE");
#else
	if (LUA_TFUNCTION != lua_getfield(L, LUA_REGISTRYINDEX, "BGFX_GET_INTERFACE")) {
		luaL_error(L, "BGFX_GET_INTERFACE is missing.");
		return;
	}
	lua_CFunction fn = lua_tocfunction(L, -1);
	if (fn == NULL) {
		luaL_error(L, "BGFX_GET_INTERFACE is not a C function.");
		return;
	}
	bgfx_interface_vtbl_t* inf = ((PFN_BGFX_GET_INTERFACE)fn)(BGFX_API_VERSION);
	if (inf == NULL) {
		luaL_error(L, "BGFX_API_VERSION (%d) mismatch.", BGFX_API_VERSION);
		return;
	}
	bgfx_inf_ = inf;
	lua_pop(L, 1);
#endif
}

#define BGFX(api) bgfx_inf_->api

#endif
