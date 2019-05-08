#define LUA_LIB
#include "common.h"

#include <stdio.h>  
extern "C"
{
#include <lua.h>  
#include <lualib.h>
#include <lauxlib.h>
}
#include <vector>
#include <string>
#include <array>

#include <set>
#include <algorithm>
#include <unordered_map>
#include <functional>
#include <sstream>


int lconvertFBX(lua_State *L);
int lconvertBGFXBin(lua_State *L);

extern "C" {
	MC_EXPORT int
	luaopen_meshconverter(lua_State *L)	{
		const struct luaL_Reg myLib[] = {
			{"convert_FBX", lconvertFBX},
			{"convert_BGFXBin", lconvertBGFXBin},
			{ NULL, NULL }
		};

		luaL_newlib(L, myLib);
		return 1;     
	}
}
