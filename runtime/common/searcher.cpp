#include "searcher.h"
#include "modules.h"
#include <bgfx/c99/bgfx.h>
#include <string.h>

#if defined(_MSC_VER)
#include <Windows.h>
#endif

static int
searcher_c(lua_State *L) {
	const luaL_Reg* modules = ant_modules();
	const char* name = luaL_checkstring(L, 1);
	for (size_t i = 0; modules[i].name; ++i) {
		if (strcmp(modules[i].name, name) == 0) {
			lua_pushcfunction(L, modules[i].func);
			lua_pushvalue(L, 1);
			return 2;
		}
	}
	lua_pushfstring(L, "\n\tno C module '%s'", name);
	return 1;
}

static void*
get_bgfx() {
    return (void*)bgfx_get_interface;
}

static void
init_bgfx(lua_State *L) {
    void* bgfx = get_bgfx();
    if (bgfx) {
        lua_pushcfunction(L, (lua_CFunction)bgfx);
        lua_setfield(L, LUA_REGISTRYINDEX, "BGFX_GET_INTERFACE");
    }
}

int
searcher_init(lua_State *L, int loadlib) {
    init_bgfx(L);
    if (LUA_TTABLE != lua_getglobal(L, "package")) {
        lua_pop(L, 1);
        return 0;
    }
    if (LUA_TTABLE != lua_getfield(L, -1, "searchers")) {
        lua_pop(L, 2);
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
    lua_pushcfunction(L, searcher_c);
    lua_seti(L, -2, 3);
    lua_pop(L, 2);
	return 1;
}
