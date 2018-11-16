#define LUA_LIB

#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
#include <Windows.h>

static int load_resource(lua_State* L, const char* type, const char* filename, const char* chunkname) {
	HRSRC rsrc = FindResourceA(NULL, filename, type);
	if (!rsrc) {
        lua_pushnil(L);
        lua_pushfstring(L, "FindResourceA error: %d", GetLastError());
		return LUA_ERRRUN;
    }
	HGLOBAL global = LoadResource(NULL, rsrc); 
	if (!global) {
        lua_pushnil(L);
        lua_pushfstring(L, "LoadResource error: %d", GetLastError());
		return LUA_ERRRUN;
    }
	void* buf = LockResource(global); 
	if (!buf) {
        lua_pushnil(L);
        lua_pushfstring(L, "LockResource error: %d", GetLastError());
		return LUA_ERRRUN;
    }
	size_t size = SizeofResource(NULL, rsrc); 
	if (!size) {
	    FreeResource(global);
        lua_pushnil(L);
        lua_pushfstring(L, "SizeofResource error: %d", GetLastError());
		return LUA_ERRRUN;
    }
    int status = luaL_loadbuffer(L, (const char*)buf, size, chunkname);
	FreeResource(global);
	return status;
}

static int lloadfile(lua_State* L) {
	const char* filename = luaL_checkstring(L, 1);
	lua_pushstring(L, "firmware://");
	lua_pushvalue(L, 1);
	lua_concat(L, 2);
	if (LUA_OK != load_resource(L, "firmware", filename, lua_tostring(L, -1))) {
		return 2;
	}
	return 1;
}

LUAMOD_API
int luaopen_firmware(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "loadfile", lloadfile },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
    return 1;
}
