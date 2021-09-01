#include "modules.h"
#include <bgfx/c99/bgfx.h>

extern "C" {
int luaopen_bgfx(lua_State* L);
int luaopen_bgfx_util(lua_State* L);
int luaopen_crypt(lua_State* L);
int luaopen_datalist(lua_State* L);
int luaopen_filesystem_cpp(lua_State* L);
int luaopen_firmware(lua_State* L);
int luaopen_hierarchy(lua_State* L);
int luaopen_hierarchy_animation(lua_State* L);
int luaopen_hierarchy_scene(lua_State *L);
//int luaopen_imgui(lua_State* L);
int luaopen_lsocket(lua_State* L);
int luaopen_math3d(lua_State* L);
int luaopen_math3d_adapter(lua_State* L);
int luaopen_platform(lua_State* L);
int luaopen_platform_timer(lua_State* L);
int luaopen_protocol(lua_State* L);
int luaopen_remotedebug(lua_State* L);
int luaopen_remotedebug_hookmgr(lua_State* L);
int luaopen_remotedebug_stdio(lua_State* L);
int luaopen_remotedebug_visitor(lua_State* L);
int luaopen_rp3d_core(lua_State* L);
int luaopen_thread(lua_State* L);
int luaopen_window(lua_State* L);
int luaopen_terrain(lua_State *L);
int luaopen_font(lua_State *L);
int luaopen_effekseer(lua_State* L);
int luaopen_ltask(lua_State* L);
int luaopen_ltask_bootstrap(lua_State* L);
int luaopen_ltask_root(lua_State* L);
int luaopen_ltask_exclusive(lua_State* L);
int luaopen_vfs(lua_State* L);
int luaopen_ecs_core(lua_State* L);
int luaopen_fastio(lua_State* L);
}

const luaL_Reg* ant_modules() {
    static const luaL_Reg modules[] = {
        { "bgfx", luaopen_bgfx },
        { "bgfx.util", luaopen_bgfx_util },
        { "bgfx_get_interface", (lua_CFunction)bgfx_get_interface },
        { "font", luaopen_font },
        { "crypt", luaopen_crypt },
        { "datalist", luaopen_datalist },
        { "filesystem.cpp", luaopen_filesystem_cpp },
        { "firmware", luaopen_firmware },
        { "hierarchy", luaopen_hierarchy },
        { "hierarchy.animation", luaopen_hierarchy_animation },
        { "hierarchy.scene", luaopen_hierarchy_scene },
        //{ "imgui", luaopen_imgui },
        { "lsocket", luaopen_lsocket },
        { "math3d", luaopen_math3d },
        { "math3d.adapter", luaopen_math3d_adapter },
        { "platform", luaopen_platform },
        { "platform.timer", luaopen_platform_timer },
        { "protocol", luaopen_protocol },
        { "remotedebug", luaopen_remotedebug },
        { "remotedebug.hookmgr", luaopen_remotedebug_hookmgr },
        { "remotedebug.stdio", luaopen_remotedebug_stdio },
        { "remotedebug.visitor", luaopen_remotedebug_visitor },
        { "rp3d.core", luaopen_rp3d_core },
        { "thread", luaopen_thread },
        { "window", luaopen_window },
        { "terrain", luaopen_terrain},
        { "effekseer", luaopen_effekseer},
        { "ltask", luaopen_ltask},
        { "ltask.bootstrap", luaopen_ltask_bootstrap},
        { "ltask.bootstrap", luaopen_ltask_bootstrap},
        { "ltask.exclusive", luaopen_ltask_exclusive},
        { "ecs.core", luaopen_ecs_core},
        { "fastio", luaopen_fastio},
        { NULL, NULL },
    };
    return modules;
}

void ant_openlibs(lua_State* L) {
    const luaL_Reg *lib;
    luaL_getsubtable(L, LUA_REGISTRYINDEX, LUA_PRELOAD_TABLE);
    for (lib = ant_modules(); lib->func; lib++) {
        lua_pushcfunction(L, lib->func);
        lua_setfield(L, -2, lib->name);
    }
    lua_pop(L, 1);

    luaL_requiref(L, "vfs", luaopen_vfs, 0);
    lua_pop(L, 1);
}
