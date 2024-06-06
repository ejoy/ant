#include <lua.hpp>

static int systemfont(lua_State* L) {
    return luaL_error(L, "Read font data failed");
}

extern "C"
int luaopen_font_util(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "systemfont", systemfont },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}
