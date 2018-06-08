#define LUA_LIB
#include <lua.h>

int iup_scintillalua_open(lua_State* L);

LUAMOD_API int 
luaopen_scintilla(lua_State *L) {
	iup_scintillalua_open(L);
	lua_getglobal(L, "iup");
	return 1;
}
