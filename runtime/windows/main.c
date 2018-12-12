#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
#include <wchar.h>
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
	const char* r = lua_pushlstring(L, ustr, rusz-1);
    allocf(ud, ustr, usz, 0);
    return r;
}

static const wchar_t hex[] = L"0123456789abcdef";

static void repo_setup(wchar_t* dir) {
	PathAppendW(dir, L".repo");
    CreateDirectoryW(dir, NULL);
    size_t sz = wcslen(dir);
    dir[sz] = L'\\';
    dir[sz+3] = L'\0';
    for (int i = 0; i < 16; ++i) {
        for (int j = 0; j < 16; ++j) {
            dir[sz+1] = hex[i];
            dir[sz+2] = hex[j];
            CreateDirectoryW(dir, NULL);
        }
    }
    dir[sz] = L'\0';
}

static void repo_dir(lua_State* L) {
	wchar_t dir[MAX_PATH] = {0};
	LPITEMIDLIST pidl = NULL;
	SHGetSpecialFolderLocation(NULL, CSIDL_PERSONAL, &pidl);
    SHGetPathFromIDListW(pidl, dir);
	PathAppendW(dir, L"ant");
    CreateDirectoryW(dir, NULL);
	PathAppendW(dir, L"runtime");
    CreateDirectoryW(dir, NULL);
    SetCurrentDirectoryW(dir);
    repo_setup(dir);
}

static int msghandler(lua_State *L) {
    const char *msg = lua_tostring(L, 1);
    if (msg == NULL) {
        lua_pushstring(L, "<null>");
    }
    luaL_traceback(L, L, msg, 1);
    return 1;
}

static void dostring(lua_State* L, const char* str) {
    lua_pushcfunction(L, msghandler);
    int err = lua_gettop(L);
    if (LUA_OK == luaL_loadbuffer(L, str, strlen(str), "=(BOOTSTRAP)")) {
        if (LUA_OK == lua_pcall(L, 0, 0, err)) {
            return;
        }
    }
    lua_writestringerror("%s\n", lua_tostring(L, -1));
}

static void createargtable(lua_State *L, int argc, wchar_t **argv) {
  lua_createtable(L, argc - 1, 0);
  for (int i = 1; i < argc; ++i) {
    lua_pushutf8string(L, argv[i], -1);
    lua_rawseti(L, -2, i);
  }
  lua_setglobal(L, "arg");
}

static int pmain(lua_State *L) {
    int argc = (int)lua_tointeger(L, 1);
    wchar_t** argv = (wchar_t **)lua_touserdata(L, 2);
    luaL_checkversion(L);
    lua_setfield(L, LUA_REGISTRYINDEX, "LUA_NOENV");
    luaL_openlibs(L);
    createargtable(L, argc, argv);
    ant_searcher_init(L, 0);
    repo_dir(L);
    dostring(L, "local fw = require 'firmware' ; assert(fw.loadfile 'bootstrap.lua')()");
    return 0;
}

int wmain(int argc, wchar_t** argv) {
    lua_State* L = luaL_newstate();
    if (!L) {
        lua_writestringerror("%s\n", "cannot create state: not enough memory");
        return 0;
    }
    lua_pushcfunction(L, &pmain);
    lua_pushinteger(L, argc);
    lua_pushlightuserdata(L, argv);
    if (LUA_OK != lua_pcall(L, 2, 0, 0)) {
        lua_writestringerror("%s\n", lua_tostring(L, -1));
    }
    lua_close(L);
    return 0;
}

#if defined(__MINGW32__)
#include "mingw_wmain.h"
#endif
