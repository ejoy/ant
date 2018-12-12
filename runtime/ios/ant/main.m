#include "ios_window.h"
#include "ios_error.h"
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include <ant.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>

static void repo_dir(lua_State* L) {
    NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString* docDir = [paths objectAtIndex:0];
    NSFileManager* fileMgr = [NSFileManager defaultManager];
    [fileMgr changeCurrentDirectoryPath:docDir];
    [fileMgr createDirectoryAtPath:@".repo/" withIntermediateDirectories:YES attributes:nil error:nil];
    for (int i = 0; i < 16; ++i) {
        for (int j = 0; j < 16; ++j) {
            NSString* dir = [NSString stringWithFormat:@".repo/%x%x", i, j];
            [fileMgr createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
        }
    }
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
    if (LUA_OK != luaL_loadbuffer(L, str, strlen(str), "=(BOOTSTRAP)")) {
        lua_error(L);
        return;
    }
    lua_call(L, 0, 0);
}

static void createargtable(lua_State *L, int argc, char **argv) {
    lua_createtable(L, argc - 1, 0);
    for (int i = 1; i < argc; ++i) {
        lua_pushstring(L, argv[i]);
        lua_rawseti(L, -2, i);
    }
    lua_setglobal(L, "arg");
}

static int pmain(lua_State *L) {
    int argc = (int)lua_tointeger(L, 1);
    char** argv = (char **)lua_touserdata(L, 2);
    luaL_checkversion(L);
    lua_setfield(L, LUA_REGISTRYINDEX, "LUA_NOENV");
    luaL_openlibs(L);
    createargtable(L, argc, argv);
    ant_searcher_init(L, 0);
    repo_dir(L);
    dostring(L, "local fw = require 'firmware' ; assert(fw.loadfile 'bootstrap.lua')()");
    return 0;
}

int main(int argc, char * argv[]) {
    @autoreleasepool {
        ios_error_handler();
        lua_State* L = luaL_newstate();
        if (!L) {
            ios_error_display("cannot create state: not enough memory");
            return 1;
        }
        lua_pushcfunction(L, msghandler);
        int err = lua_gettop(L);
        lua_pushcfunction(L, &pmain);
        lua_pushinteger(L, argc);
        lua_pushlightuserdata(L, argv);
        if (LUA_OK != lua_pcall(L, 2, 0, err)) {
            ios_error_display(lua_tostring(L, -1));
            lua_close(L);
            return 1;
        }
        int res = UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
        lua_close(L);
        return res;
    }
}
