#include <lua.hpp>
#include <ant.h>
#include <shlobj.h>
#include <shlwapi.h>

static const char* lua_pushutf8string(lua_State* L, const wchar_t* wstr, size_t wsz) {
    int usz = WideCharToMultiByte(CP_UTF8, 0, wstr, wsz, 0, 0, NULL, NULL);
	if (usz <= 0) {
        luaL_error(L, "convert to utf-8 string fail.");
        return 0;
    }
    void *ud;
    lua_Alloc allocf = lua_getallocf(L, &ud);
    char* ustr = (char*)allocf(ud, NULL, 0, usz);
	if (!ustr) {
        luaL_error(L, "convert to utf-8 string fail.");
        return 0;
    }
    int rusz = WideCharToMultiByte(CP_UTF8, 0, wstr, wsz, ustr, usz, NULL, NULL);
	if (rusz <= 0) {
        allocf(ud, ustr, usz, 0);
        luaL_error(L, "convert to utf-8 string fail.");
        return 0;
    }
	const char* r = lua_pushlstring(L, ustr, rusz);
    allocf(ud, ustr, usz, 0);
    return r;
}

static const char* repoinit(lua_State* L, const wchar_t* name) {
	wchar_t dir[MAX_PATH] = {0};
	LPITEMIDLIST pidl = NULL;
	SHGetSpecialFolderLocation(NULL, CSIDL_PERSONAL, &pidl);
    SHGetPathFromIDListW(pidl, dir);
	PathAppendW(dir, name);
    SetCurrentDirectoryW(dir);

	PathAppendW(dir, L"firmware");
	PathAppendW(dir, L"init.lua");
	return lua_pushutf8string(L, dir, -1);
}

static int msghandler (lua_State *L) {
    const char *msg = lua_tostring(L, 1);
    if (msg == NULL) {
        lua_pushstring(L, "<null>");
    }
    luaL_traceback(L, L, msg, 1);
    return 1;
}

static void dofile(lua_State* L, const char* name) {
    lua_pushcfunction(L, msghandler);
    int err = lua_gettop(L);
    if (LUA_OK == luaL_loadfile(L, name)) {
        if (LUA_OK == lua_pcall(L, 0, 0, err)) {
            return;
        }
    }
    lua_writestringerror("%s\n", lua_tostring(L, -1));
}

static int pmain (lua_State *L) {
    int argc = (int)lua_tointeger(L, 1);
    wchar_t** argv = (wchar_t **)lua_touserdata(L, 2);
    luaL_checkversion(L);
    lua_setfield(L, LUA_REGISTRYINDEX, "LUA_NOENV");
    luaL_openlibs(L);
    ant_searcher_init(L);
    if (argc <= 1) {
        return luaL_error(L, "Need repo name");
    }
    dofile(L, repoinit(L, argv[1]));
    return 0;
}

int wmain(int argc, wchar_t** argv) {
    lua_State* L = luaL_newstate();
    if (!L) {
        lua_writestringerror("%s\n", "cannot create state: not enough memory");
        return EXIT_FAILURE;
    }
    lua_pushcfunction(L, &pmain);
    lua_pushinteger(L, argc);
    lua_pushlightuserdata(L, argv);
    if (LUA_OK != lua_pcall(L, 2, 1, 0)) {
        const char* msg = lua_tostring(L, -1);
        lua_writestringerror("%s\n", msg);
        lua_close(L);
        return EXIT_FAILURE;
    }
    lua_close(L);
    return EXIT_SUCCESS;
}

#if defined(__MINGW32__)
#include "mingw_wmain.h"
#endif
