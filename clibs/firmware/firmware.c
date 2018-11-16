#define LUA_LIB

#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
#include <Windows.h>

static int load_resource(lua_State* L, const char* type, const char* filename) {
	HRSRC rsrc = FindResourceA(NULL, filename, type);
	if (!rsrc) {
        lua_pushnil(L);
        lua_pushfstring(L, "FindResourceA error: %d", GetLastError());
		return 2;
    }
	HGLOBAL global = LoadResource(NULL, rsrc); 
	if (!global) {
        lua_pushnil(L);
        lua_pushfstring(L, "LoadResource error: %d", GetLastError());
		return 2;
    }
	void* buf = LockResource(global); 
	if (!buf) {
        lua_pushnil(L);
        lua_pushfstring(L, "LockResource error: %d", GetLastError());
		return 2;
    }
	size_t size = SizeofResource(NULL, rsrc); 
	if (!size) {
	    FreeResource(global);
        lua_pushnil(L);
        lua_pushfstring(L, "SizeofResource error: %d", GetLastError());
		return 2;
    }
    lua_pushlstring(L, (const char*)buf, size);
	FreeResource(global);
	return 1;
}

static int lload(lua_State* L) {
	return load_resource(L, luaL_checkstring(L, 1), luaL_checkstring(L, 2));
}

LUAMOD_API
int luaopen_firmware(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "load", lload },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
    return 1;
}
