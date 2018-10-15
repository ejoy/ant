//
//  preload.c
//  ant_ios
//
//  Created by ejoy on 2018/8/9.
//  Copyright © 2018年 ejoy. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <stdio.h>
#import <string.h>
#import "preload.h"

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
LUAMOD_API int luaopen_redirectfd(lua_State *L);
void luaopen_lanes_embedded(lua_State *L, lua_CFunction _luaopen_lanes);

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
    {"redirectfd", luaopen_redirectfd},
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
static int default_luaopen_lanes(lua_State *L) {
    NSString *lanes_lua = [[NSBundle mainBundle] resourcePath];
    lanes_lua = [lanes_lua stringByAppendingString:@"/fw/lanes.lua"];
    int rc = luaL_loadfile( L, [lanes_lua UTF8String]) || lua_pcall( L, 0, 1, 0);
    if( rc != LUA_OK) {
        return luaL_error( L, "failed to initialize embedded Lanes");
    }
    return 1;
}

static int custom_on_state_create(lua_State *L) {
    //luaL_requiref(L, "preloadc", luaopen_preloadc, 0);
    lua_pushcfunction(L, replace_csearcher);
    if(lua_pcall(L, 0, 0, 0) != 0)
    {
        const char *msg = lua_tostring(L, -1);
        
        if(msg) {
            printf("------- error!!! -------- \n %s\n", msg);
            
            //send a log
            lua_getglobal(L, "sendlog");
            if(lua_isfunction(L, -1)) {
                lua_pushstring(L, "Device");
                lua_pushstring(L, msg);
                lua_pcall(L, 2, 0, 0);
            }
            
            luaL_traceback(L, L, msg, 1);
        }
    }
    
    lua_pop(L, 1);
    
    return 0;
}

static int lpreloadc(lua_State* L) {
    luaopen_lanes_embedded(L, default_luaopen_lanes);
    custom_on_state_create(L);
    lua_pushcfunction(L, custom_on_state_create);
    lua_setglobal(L, "custom_on_state_create");
    
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
