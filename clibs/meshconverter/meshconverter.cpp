#define LUA_LIB

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
//int lconvertOZZMesh(lua_State *L);

static const struct luaL_Reg myLib[] = {	
	{"convert_FBX", lconvertFBX},
	{"convert_BGFXBin", lconvertBGFXBin},	
	{ NULL, NULL }      
};

extern "C" {
	// not use LUAMOD_API here, when a dynamic lib linking in GCC compiler with static lib which limit symbol export, 
	// it will cause this dynamic lib not export all symbols by default
#if defined(_MSC_VER)
	//  Microsoft 
#define EXPORT __declspec(dllexport)
#define IMPORT __declspec(dllimport)
#elif defined(__GNUC__)
	//  GCC
//#define EXPORT	__attribute__(visibility("default"))
	// need force export, visibility("default") will follow static lib setting
#define EXPORT	__attribute__((dllexport))
#define IMPORT
#else
	//  do nothing and hope for the best?
#define EXPORT
#define IMPORT
#pragma warning Unknown dynamic link import/export semantics.
#endif
	EXPORT int
	luaopen_assimplua(lua_State *L)	{
		luaL_newlib(L, myLib);
		return 1;     
	}
}

