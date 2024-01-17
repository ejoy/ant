#include "modules.h"
#include <lua.h>
#include <lauxlib.h>
#include <bgfx/c99/bgfx.h>

int luaopen_bee_filesystem(lua_State* L);
int luaopen_bee_select(lua_State* L);
int luaopen_bee_serialization(lua_State* L);
int luaopen_bee_socket(lua_State* L);
int luaopen_bee_thread(lua_State* L);
int luaopen_bee_platform(lua_State* L);
int luaopen_bee_time(lua_State* L);
int luaopen_bgfx(lua_State* L);
int luaopen_bgfx_util(lua_State* L);
int luaopen_datalist(lua_State* L);
int luaopen_ozz(lua_State* L);
int luaopen_math3d(lua_State* L);
int luaopen_math3d_adapter(lua_State* L);
#ifdef MATH3D_ADAPTER_TEST
int luaopen_math3d_adapter_test(lua_State *L);
#endif 
int luaopen_protocol(lua_State* L);
int luaopen_luadebug(lua_State* L);
int luaopen_luadebug_hookmgr(lua_State* L);
int luaopen_luadebug_stdio(lua_State* L);
int luaopen_luadebug_visitor(lua_State* L);
int luaopen_rmlui(lua_State* L);
int luaopen_window(lua_State* L);
int luaopen_noise(lua_State *L);
int luaopen_textureman_client(lua_State *L);
int luaopen_textureman_server(lua_State *L);
int luaopen_programan_client(lua_State *L);
int luaopen_programan_server(lua_State *L);
int luaopen_fmod(lua_State* L);
int luaopen_font(lua_State *L);
int luaopen_font_manager(lua_State *L);
int luaopen_font_truetype(lua_State *L);
int luaopen_font_util(lua_State *L);
int luaopen_efk(lua_State* L);
int luaopen_effekseer_callback(lua_State* L);
int luaopen_ltask(lua_State* L);
int luaopen_ltask_bootstrap(lua_State* L);
int luaopen_ltask_root(lua_State* L);
int luaopen_ltask_exclusive(lua_State* L);
int luaopen_vfs(lua_State* L);
int luaopen_ecs_core(lua_State* L);
int luaopen_ecs_components(lua_State* L);
int luaopen_ecs_util(lua_State* L);
int luaopen_fastio(lua_State* L);
int luaopen_material_arena(lua_State *L);
int luaopen_material_core(lua_State *L);
int luaopen_render_material(lua_State *L);
int luaopen_render_queue(lua_State *L);
int luaopen_system_render(lua_State *L);
int luaopen_render_stat(lua_State *L);
int luaopen_motion_sampler(lua_State *L);
int luaopen_motion_tween(lua_State *L);
int luaopen_image(lua_State* L);
int luaopen_imgui(lua_State* L);
#if BX_PLATFORM_IOS
int luaopen_ios(lua_State* L);
#endif
#if BX_PLATFORM_ANDROID
int luaopen_android(lua_State* L);
#endif
#if defined(ANT_RUNTIME)
int luaopen_firmware(lua_State* L);
#else
int luaopen_bee_filewatch(lua_State* L);
int luaopen_bee_subprocess(lua_State* L);
int luaopen_filedialog(lua_State* L);
int luaopen_imgui_widgets(lua_State* L);
#endif
int luaopen_system_scene(lua_State* L);
int luaopen_system_cull(lua_State* L);
int luaopen_zip(lua_State* L);
int luaopen_httpc(lua_State *L);

void ant_loadmodules(lua_State* L) {
    static const luaL_Reg modules[] = {
        { "bee.filesystem", luaopen_bee_filesystem },
        { "bee.select", luaopen_bee_select },
        { "bee.serialization", luaopen_bee_serialization },
        { "bee.socket", luaopen_bee_socket },
        { "bee.thread", luaopen_bee_thread },
        { "bee.platform", luaopen_bee_platform },
        { "bee.time", luaopen_bee_time },
        { "bgfx", luaopen_bgfx },
        { "bgfx.util", luaopen_bgfx_util },
        { "font", luaopen_font },
        { "font.manager", luaopen_font_manager },
        { "font.truetype", luaopen_font_truetype },
        { "font.util", luaopen_font_util },
        { "datalist", luaopen_datalist },
        { "ozz", luaopen_ozz },
        { "math3d", luaopen_math3d },
        { "math3d.adapter", luaopen_math3d_adapter },
#ifdef MATH3D_ADAPTER_TEST
        { "math3d.adapter.test", luaopen_math3d_adapter_test},
#endif
        { "protocol", luaopen_protocol },
        { "luadebug", luaopen_luadebug },
        { "luadebug.hookmgr", luaopen_luadebug_hookmgr },
        { "luadebug.stdio", luaopen_luadebug_stdio },
        { "luadebug.visitor", luaopen_luadebug_visitor },
        { "rmlui", luaopen_rmlui },
        { "window", luaopen_window },
        { "noise", luaopen_noise },
        { "textureman.client", luaopen_textureman_client },
        { "textureman.server", luaopen_textureman_server },
        { "programan.client", luaopen_programan_client },
        { "programan.server", luaopen_programan_server },
        { "efk", luaopen_efk},
        { "effekseer.callback", luaopen_effekseer_callback},
        { "fmod", luaopen_fmod},
        { "ltask", luaopen_ltask},
        { "ltask.bootstrap", luaopen_ltask_bootstrap},
        { "ltask.bootstrap", luaopen_ltask_bootstrap},
        { "ltask.exclusive", luaopen_ltask_exclusive},
        { "ecs.core", luaopen_ecs_core},
        { "ecs.components", luaopen_ecs_components},
        { "ecs.util", luaopen_ecs_util},
        { "fastio", luaopen_fastio},
        { "render.material.arena",  luaopen_material_arena},
	{ "render.material.core",   luaopen_material_core},
        { "render.render_material", luaopen_render_material},
        { "render.queue",           luaopen_render_queue},
        { "system.render",      luaopen_system_render},
        { "render.stat",        luaopen_render_stat},
        { "motion.sampler",     luaopen_motion_sampler},
        { "motion.tween",       luaopen_motion_tween},
        { "image", luaopen_image },
        { "imgui", luaopen_imgui },
#if BX_PLATFORM_IOS
        { "ios", luaopen_ios },
#endif
#if BX_PLATFORM_ANDROID
        { "android", luaopen_android },
#endif
#if defined(ANT_RUNTIME)
        { "firmware", luaopen_firmware },
#else
        { "bee.filewatch", luaopen_bee_filewatch },
        { "bee.subprocess", luaopen_bee_subprocess },
        { "filedialog", luaopen_filedialog },
        { "imgui.widgets", luaopen_imgui_widgets },
#endif
        { "system.scene", luaopen_system_scene },
        { "cull.core", luaopen_system_cull},
        { "zip", luaopen_zip },
        { "httpc", luaopen_httpc },
        { NULL, NULL },
    };

    const luaL_Reg *lib;
    luaL_getsubtable(L, LUA_REGISTRYINDEX, LUA_PRELOAD_TABLE);
    for (lib = modules; lib->func; lib++) {
        lua_pushcfunction(L, lib->func);
        lua_setfield(L, -2, lib->name);
    }
    lua_pop(L, 1);

    luaL_requiref(L, "vfs", luaopen_vfs, 0);
    lua_pop(L, 1);
}
