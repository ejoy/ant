#include <lua.h>
#include <lauxlib.h>
#include "lua_api_register.h"

static int
lregister(lua_State *L) {
	lua_CFunction f = lua_tocfunction(L, 1);
	if (f == NULL || lua_getupvalue(L, 1, 1))
		return luaL_error(L, "Need register function");
	lua_api_register reg = (lua_api_register)f;
	struct lua_api api = {
		LUA_VERSION_NUM,

		$API_STRUCT$
	};
	lua_CFunction call = reg(api);
	if (call == NULL)
		return luaL_error(L, "Init luaforward error");
	lua_pushcfunction(L, call);
	return 1;
}

int
luaopen_luaforward(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "register", lregister },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}
