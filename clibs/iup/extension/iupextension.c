#define LUA_LIB

#include <lua.h>
#include <lauxlib.h>
#include <stdlib.h>
#include <windows.h>
#include <string.h>

#include "iup.h"
#include "iuplua.h"
#include "iupwin_str.h"
#include "shell.h"


static int
licon(lua_State *L) {
	const char *filename = luaL_checkstring(L, 1);
	TCHAR * tfilename = iupwinStrToSystemFilename(filename);
	struct icon_info info;
	int large;
	if (lua_isnoneornil(L, 2)) {
		large = 1;
	} else {
		const char * size = luaL_checkstring(L, 2);
		if (strcmp(size, "small") == 0) {
			large = 0;
		} else if (strcmp(size, "large") == 0) {
			large = 1;
		} else {
			luaL_error(L, "Unsupport size %s", size);
		}
	}
	void * mem = shell_geticon(tfilename, &info, large);
	if (mem == NULL)
		return 0;

	Ihandle *ih = IupImageRGBA(info.width, info.height, mem);
	iuplua_pushihandle(L, ih);
	lua_pushinteger(L, info.width);
	lua_pushinteger(L, info.height);
	shell_releaseicon(&info);

	return 3;
}

static int
licon_with_size(lua_State *L) {
	const char *filename = luaL_checkstring(L, 1);
	TCHAR * tfilename = iupwinStrToSystemFilename(filename);
	struct icon_info info;
	int size;
	if (lua_isnoneornil(L, 2)) {
		size = 1;
	} else {
		size = luaL_checkinteger(L, 2);
	}
	void * mem = shell_geticon_with_size(tfilename, &info, size);
	if (mem == NULL)
		return 0;

	Ihandle *ih = IupImageRGBA(info.width, info.height, mem);
	iuplua_pushihandle(L, ih);
	lua_pushinteger(L, info.width);
	lua_pushinteger(L, info.height);
	shell_releaseicon(&info);

	return 3;
}

//static int co_initialize(lua_State *L) {
//	shell_co_initialize();
//	return 0;
//}
//
//static int co_uninitialize(lua_State *L) {
//	shell_co_uninitialize();
//	return 0;
//}


LUAMOD_API int
luaopen_iupextension(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "icon" , licon },
		{ "icon_with_size" , licon_with_size },
		//{ "co_initialize" , co_initialize },
		//{ "co_uninitialize" , co_uninitialize },
		{ NULL, NULL },
	};

	luaL_newlib(L, l);

	return 1;
}
