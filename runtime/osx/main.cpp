#include <lua.hpp>
#include <ant.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>

#define MKDIR_OPTION (S_IRUSR | S_IWUSR | S_IXUSR | S_IRGRP | S_IWGRP | S_IXGRP | S_IROTH | S_IXOTH)

static const wchar_t hex[] = L"0123456789abcdef";

static void repo_dir(lua_State* L) {
    const char* home = getenv("HOME");
    chdir(home);
    
    mkdir("./ant/", MKDIR_OPTION);
    mkdir("./ant/runtime/", MKDIR_OPTION);
    mkdir("./ant/runtime/.repo/", MKDIR_OPTION);
    char dir[] = "./ant/runtime/.repo/00/";
    size_t sz = sizeof("./ant/runtime/.repo");
    for (int i = 0; i < 16; ++i) {
        for (int j = 0; j < 16; ++j) {
            dir[sz+0] = hex[i];
            dir[sz+1] = hex[j];
            mkdir(dir, MKDIR_OPTION);
        }
    }
    chdir("./ant/runtime/");
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

int main(int argc, char** argv) {
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
