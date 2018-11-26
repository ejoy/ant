#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

static void hook_openlibs(lua_State *L);

#define luaL_openlibs(L) hook_openlibs(L)

#if defined(_WIN32)
#include "utf8_lua.c"
#include "utf8_unicode.c"
#else
#include "lua.c"
#endif

#undef luaL_openlibs

#include "ant.h"

static void hook_openlibs(lua_State *L) {
    luaL_openlibs(L);
    ant_searcher_init(L, 1);
}
