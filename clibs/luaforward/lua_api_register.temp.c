#include "lua_api_register.h"
#include <lua.h>
#include <lauxlib.h>
#include <stdarg.h>
#include <assert.h>
#include <stdio.h>

static struct lua_api API;

$API_IMPL$

LUA_API
const char *lua_pushfstring (lua_State *L, const char *fmt, ...) {
	const char *ret;
	va_list argp;
	va_start(argp, fmt);
	ret = API.lua_pushvfstring(L, fmt, argp);
	va_end(argp);
	return ret;
}


LUA_API int
lua_gc (lua_State *L, int what, ...) {
	va_list argp;
	va_start(argp, what);
	int p1 = va_arg(argp, int);
	int p2 = va_arg(argp, int);
	int p3 = va_arg(argp, int);
	va_end(argp);
	return API.lua_gc(L, what, p1, p2, p3);
}

LUA_API int
luaL_error(lua_State *L, const char *fmt, ...) {
	va_list argp;
	va_start(argp, fmt);
	luaL_where(L, 1);
	lua_pushvfstring(L, fmt, argp);
	va_end(argp);
	lua_concat(L, 2);
	return lua_error(L);
}

LUAMOD_API const char *
luaapi_init(struct lua_api * api) {
	if (api->version != LUA_VERSION_NUM)
		return "Invalid Lua API version";
	API = *api;

	return NULL;
}