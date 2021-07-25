#ifndef lua_bgfx_interface_h
#define lua_bgfx_interface_h

#include <lua.h>
#include <lauxlib.h>
#include <bgfx/c99/bgfx.h>

#if defined(__cplusplus)
template <typename T>
struct global { static inline T v = T(); };
#define BGFX_INTERFACE (global<bgfx_interface_vtbl_t*>::v)
#else
static bgfx_interface_vtbl_t* bgfx_inf_ = 0;
#define BGFX_INTERFACE (bgfx_inf_)
#endif

static inline void
init_interface(lua_State* L) {
	if (BGFX_INTERFACE) {
		return;
	}
#ifdef BGFX_STATIC_LINK
	bgfx_interface_vtbl_t* inf = bgfx_get_interface(BGFX_API_VERSION);
	if (inf == NULL) {
		luaL_error(L, "BGFX_API_VERSION (%d) mismatch.", BGFX_API_VERSION);
		return;
	}
	BGFX_INTERFACE = inf;
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
	BGFX_INTERFACE = inf;
	lua_pop(L, 1);
#endif
}

#define BGFX(api) BGFX_INTERFACE->api
#define BGFX_ENCODER(api, encoder, ...) (encoder ? (BGFX(encoder_##api)( encoder, ## __VA_ARGS__ )) : BGFX(api)( __VA_ARGS__ ))

#endif
