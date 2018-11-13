#include "ant.h"
#include <lua.hpp>
#include <map>
#include <string>

#include "ant_module_declar.h"
std::map<std::string, lua_CFunction> g_modules = {
#include "ant_module_define.h"
};

int ant_searcher_c(lua_State *L) {
	size_t len = 0;
	const char* name = luaL_checklstring(L, 1, &len);
	auto it = g_modules.find(std::string(name, len));
	if (it == g_modules.end()) {
		lua_pushfstring(L, "\n\tno C module '%s'", name);
		return 1;
	}
	lua_pushcfunction(L, it->second);
	lua_pushvalue(L, 1);
	return 2;
}

extern "C"
int ant_searcher_init(lua_State *L) {
    if (LUA_TTABLE != lua_getglobal(L, "package")) {
        return 0;
    }
    if (LUA_TTABLE != lua_getfield(L, -1, "searchers")) {
        lua_pop(L, 1);
        return 0;
    }
    lua_pushcfunction(L, ant_searcher_c);
    lua_seti(L, -2, 3);
    lua_pushnil(L);
    lua_seti(L, -2, 4);
    lua_pop(L, 2);
	return 1;
}
