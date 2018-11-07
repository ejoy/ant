#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

static void hook_openlibs(lua_State *L);

#define luaL_openlibs(L) hook_openlibs(L)
#include "lua.c"
#undef luaL_openlibs

int init_searcher(lua_State *L);

static void hook_openlibs(lua_State *L) {
    luaL_openlibs(L);
    init_searcher(L);
}
