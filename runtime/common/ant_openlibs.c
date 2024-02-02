#define linit_c
#define LUA_LIB

#include <stddef.h>
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
#include "modules.h"

static const luaL_Reg loadedlibs[] = {
    {LUA_GNAME, luaopen_base},
    {LUA_LOADLIBNAME, luaopen_package},
    {LUA_COLIBNAME, luaopen_coroutine},
    {LUA_TABLIBNAME, luaopen_table},
    {LUA_IOLIBNAME, luaopen_io},
    {LUA_OSLIBNAME, luaopen_os},
    {LUA_STRLIBNAME, luaopen_string},
    {LUA_MATHLIBNAME, luaopen_math},
    {LUA_UTF8LIBNAME, luaopen_utf8},
    {LUA_DBLIBNAME, luaopen_debug},
    {NULL, NULL}
};

#if LUA_VERSION_NUM >= 505
LUALIB_API void luaL_openselectedlibs (lua_State *L, int mask) {
#else
LUALIB_API void luaL_openlibs (lua_State *L) {
#endif
    const luaL_Reg *lib;
    for (lib = loadedlibs; lib->func; lib++) {
        luaL_requiref(L, lib->name, lib->func, 1);
        lua_pop(L, 1);  /* remove lib */
    }
    ant_loadmodules(L);
}
