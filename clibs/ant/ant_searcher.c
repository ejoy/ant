#include <lua.h>
#include <lauxlib.h>

#include "ant.h"
#include <string.h>

#include "ant_module_declar.h"
static const luaL_Reg g_modules[] = {
#include "ant_module_define.h"
	{ NULL, NULL },
};

int
ant_searcher_c(lua_State *L) {
	const char* name = luaL_checkstring(L, 1);
	int i;
	for (i=0;g_modules[i].name;i++) {
		if (strcmp(g_modules[i].name, name) == 0) {
			lua_pushcfunction(L, g_modules[i].func);
			lua_pushvalue(L, 1);
			return 2;
		}
	}

	lua_pushfstring(L, "\n\tno C module '%s'", name);
	return 1;
}

int
ant_searcher_init(lua_State *L, int loadlib) {
    if (LUA_TTABLE != lua_getglobal(L, "package")) {
        return 0;
    }
    if (LUA_TTABLE != lua_getfield(L, -1, "searchers")) {
        lua_pop(L, 1);
        return 0;
    }
    if (loadlib) {
        lua_geti(L, -1, 4);
        lua_seti(L, -2, 5);
        lua_geti(L, -1, 3);
        lua_seti(L, -2, 4);
    }
    else {
        lua_pushnil(L);
        lua_seti(L, -2, 4);
    }
    lua_pushcfunction(L, ant_searcher_c);
    lua_seti(L, -2, 3);
    lua_pop(L, 2);
	return 1;
}
