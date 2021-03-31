#include "modules.h"

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
}

const luaL_Reg* ant_modules() {
    static const luaL_Reg modules[] = {
        { "bgfx", luaopen_bgfx },
        { "bgfx.util", luaopen_bgfx_util },
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
        { NULL, NULL },
    };
    return modules;
}
