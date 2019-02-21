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
	shell_releaseicon(&info);

	return 1;
}

LUAMOD_API int
luaopen_iupextension(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "icon" , licon },
		{ NULL, NULL },
	};

	luaL_newlib(L, l);

	return 1;
}
