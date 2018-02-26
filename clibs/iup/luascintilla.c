#define LUA_LIB
#include <lua.h>

int iup_scintillalua_open(lua_State* L);

LUAMOD_API int 
luaopen_scintilla(lua_State *L) {
	iup_scintillalua_open(L);
	lua_getglobal(L, "iup");
	return 1;
}

// just for simple workaround iup build in msvc cause the linking error in iupwindows_main.c file
// the appropriate way the handle this should add a new msvc project the same as iupcore project except iupwindows_main.c/iupwindows_info.c files
#ifdef _MSC_VER 
int main(int argc, char **argv) {
	return 0;
}
#endif //_MSC_VER 
