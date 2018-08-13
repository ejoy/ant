//
//  preload.c
//  ant_ios
//
//  Created by ejoy on 2018/8/9.
//  Copyright © 2018年 ejoy. All rights reserved.
//

#include "preload.h"


#include <lua.h>
#include <lauxlib.h>
#include <stdio.h>
#include <string.h>

//#define PRELOAD(x) { #x, luaopen_##x }
LUAMOD_API int luaopen_crypt(lua_State *L);
LUAMOD_API int luaopen_lsocket(lua_State *L);
LUAMOD_API int luaopen_bgfx(lua_State *L);
LUAMOD_API int luaopen_bgfx_util(lua_State *L);
LUAMOD_API int luaopen_bgfx_baselib(lua_State *L);
LUAMOD_API int luaopen_bgfx_terrain(lua_State *L);
LUAMOD_API int luaopen_bgfx_nuklear(lua_State *L);

LUAMOD_API int luaopen_math3d(lua_State *L);
LUAMOD_API int luaopen_lfs(lua_State *L);
LUAMOD_API int luaopen_lodepnglua(lua_State *L);
LUAMOD_API int luaopen_memoryfile (lua_State *L);
LUAMOD_API int luaopen_assimplua(lua_State *L);

LUAMOD_API int luaopen_debugger_hookmgr(lua_State *L);
LUAMOD_API int luaopen_debugger_backend(lua_State *L);
LUAMOD_API int luaopen_debugger_frontend(lua_State *L);
LUAMOD_API int luaopen_clonefunc(lua_State *L);
LUAMOD_API int luaopen_cjson_safe(lua_State *L);

LUAMOD_API int luaopen_remotedebug(lua_State *L);

static const luaL_Reg preload[] = {
    {"crypt", luaopen_crypt},
    {"lsocket", luaopen_lsocket},
    {"bgfx", luaopen_bgfx},
    {"bgfx.util", luaopen_bgfx_util},
    {"bgfx.baselib", luaopen_bgfx_baselib},
    {"lterrain", luaopen_bgfx_terrain},
    {"bgfx.nuklear", luaopen_bgfx_nuklear},
    {"math3d", luaopen_math3d},
    {"winfile", luaopen_lfs},
    {"assimplua", luaopen_assimplua},
    {"lodepnglua", luaopen_lodepnglua},
    {"memoryfile", luaopen_memoryfile},
    {"debugger.hookmgr", luaopen_debugger_hookmgr},
    {"debugger.backend", luaopen_debugger_backend},
    {"debugger.frontend", luaopen_debugger_frontend},
    {"clonefunc", luaopen_clonefunc},
    {"cjson", luaopen_cjson_safe},
    {"remotedebug", luaopen_remotedebug},
    
    { NULL, NULL },
};

static int
preload_searcher(lua_State *L) {
    const char * modname = luaL_checkstring(L,1);
    printf("searching for %s\n", modname);
    int i;
    for (i=0;preload[i].name != NULL;i++) {
        if (strcmp(modname, preload[i].name) == 0) {
            lua_pushcfunction(L, preload[i].func);
            return 1;
        }
    }
    lua_pushfstring(L, "\n\tno preload C module '%s'", modname);
    return 1;
}

static void
replace_csearcher(lua_State *L) {
    if (lua_getglobal(L, "package") != LUA_TTABLE) {
        luaL_error(L, "No package");
    }
    
    lua_pushcfunction(L, preload_searcher);
    lua_setfield(L, -2, "searcher_C");
    
    if (lua_getfield(L, -1, "searchers") != LUA_TTABLE) {
        luaL_error(L, "No package.searchers");
    }
    lua_pushcfunction(L, preload_searcher);
    lua_seti(L, -2, 3);
    lua_pop(L, 2);
}

static int lpreloadc(lua_State* L){
    replace_csearcher(L);
    return 0;
}

int get_cfuncs(lua_State* L) {
    luaL_checkversion(L);
    luaL_Reg f[] = {
        {"preloadc", lpreloadc},
        {NULL, NULL},
    };
    luaL_newlib(L, f);
    return 1;
}
