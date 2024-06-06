#include "modules.h"
#include <lua.h>
#include <lauxlib.h>
#include <bgfx/c99/bgfx.h>

int luaopen_android(lua_State* L);
int luaopen_bee_channel(lua_State* L);
int luaopen_bee_debugging(lua_State* L);
int luaopen_bee_epoll(lua_State* L);
int luaopen_bee_filesystem(lua_State* L);
int luaopen_bee_filewatch(lua_State* L);
int luaopen_bee_platform(lua_State* L);
int luaopen_bee_select(lua_State* L);
int luaopen_bee_serialization(lua_State* L);
int luaopen_bee_socket(lua_State* L);
int luaopen_bee_subprocess(lua_State* L);
int luaopen_bee_sys(lua_State* L);
int luaopen_bee_thread(lua_State* L);
int luaopen_bee_time(lua_State* L);
int luaopen_bee_windows(lua_State* L);
int luaopen_bgfx(lua_State* L);
int luaopen_bgfx_util(lua_State* L);
int luaopen_datalist(lua_State* L);
int luaopen_ecs_core(lua_State* L);
int luaopen_ecs_components(lua_State* L);
int luaopen_ecs_util(lua_State* L);
int luaopen_efk(lua_State* L);
int luaopen_effekseer_callback(lua_State* L);
int luaopen_fastio(lua_State* L);
int luaopen_filedialog(lua_State* L);
int luaopen_firmware(lua_State* L);
int luaopen_fmod(lua_State* L);
int luaopen_font(lua_State *L);
int luaopen_font_manager(lua_State *L);
int luaopen_font_truetype(lua_State *L);
int luaopen_font_util(lua_State *L);
int luaopen_httpc(lua_State *L);
int luaopen_image(lua_State* L);
int luaopen_imgui(lua_State* L);
int luaopen_imgui_backend(lua_State* L);
int luaopen_imgui_internal(lua_State* L);
int luaopen_imgui_widgets(lua_State* L);
int luaopen_ios(lua_State* L);
int luaopen_ltask_bootstrap(lua_State* L);
int luaopen_luadebug(lua_State* L);
int luaopen_luadebug_hookmgr(lua_State* L);
int luaopen_luadebug_stdio(lua_State* L);
int luaopen_luadebug_visitor(lua_State* L);
int luaopen_material_arena(lua_State *L);
int luaopen_material_core(lua_State *L);
int luaopen_math3d(lua_State* L);
int luaopen_math3d_adapter(lua_State* L);
int luaopen_math3d_adapter_test(lua_State *L);
int luaopen_motion_sampler(lua_State *L);
int luaopen_motion_tween(lua_State *L);
int luaopen_noise(lua_State *L);
int luaopen_ozz(lua_State* L);
int luaopen_ozz_offline(lua_State* L);
int luaopen_protocol(lua_State* L);
int luaopen_programan_client(lua_State *L);
int luaopen_programan_server(lua_State *L);
int luaopen_render_material(lua_State *L);
int luaopen_render_queue(lua_State *L);
int luaopen_render_mesh(lua_State *L);
int luaopen_render_cache(lua_State *L);
int luaopen_rmlui(lua_State* L);
int luaopen_system_cull(lua_State* L);
int luaopen_system_render(lua_State *L);
int luaopen_entity_drawer(lua_State *L);
int luaopen_system_scene(lua_State* L);
int luaopen_textureman_client(lua_State *L);
int luaopen_textureman_server(lua_State *L);
int luaopen_vfs(lua_State* L);
int luaopen_window(lua_State* L);
int luaopen_window_ios(lua_State* L);
int luaopen_zip(lua_State* L);
int luaopen_cell_core(lua_State *L);

void ant_loadmodules(lua_State* L) {
    static const luaL_Reg modules[] = {
        { "bee.channel", luaopen_bee_channel },
        { "bee.debugging", luaopen_bee_debugging },
        { "bee.epoll", luaopen_bee_epoll },
        { "bee.filesystem", luaopen_bee_filesystem },
        { "bee.select", luaopen_bee_select },
        { "bee.serialization", luaopen_bee_serialization },
        { "bee.socket", luaopen_bee_socket },
        { "bee.sys", luaopen_bee_sys },
        { "bee.thread", luaopen_bee_thread },
        { "bee.platform", luaopen_bee_platform },
        { "bee.time", luaopen_bee_time },
        { "bgfx", luaopen_bgfx },
        { "bgfx.util", luaopen_bgfx_util },
        { "font", luaopen_font },
        { "font.manager", luaopen_font_manager },
        { "font.truetype", luaopen_font_truetype },
        { "datalist", luaopen_datalist },
        { "ozz", luaopen_ozz },
        { "math3d", luaopen_math3d },
        { "math3d.adapter", luaopen_math3d_adapter },
#ifdef MATH3D_ADAPTER_TEST
        { "math3d.adapter.test", luaopen_math3d_adapter_test},
#endif
        { "protocol", luaopen_protocol },
#if LUA_VERSION_NUM < 505
        { "luadebug", luaopen_luadebug },
        { "luadebug.hookmgr", luaopen_luadebug_hookmgr },
        { "luadebug.stdio", luaopen_luadebug_stdio },
        { "luadebug.visitor", luaopen_luadebug_visitor },
#endif
        { "rmlui", luaopen_rmlui },
        { "noise", luaopen_noise },
        { "textureman.client", luaopen_textureman_client },
        { "textureman.server", luaopen_textureman_server },
        { "programan.client", luaopen_programan_client },
        { "programan.server", luaopen_programan_server },
        { "efk", luaopen_efk},
        { "effekseer.callback", luaopen_effekseer_callback},
        { "fmod", luaopen_fmod},
        { "ltask.bootstrap", luaopen_ltask_bootstrap},
        { "ecs.core", luaopen_ecs_core},
        { "ecs.components", luaopen_ecs_components},
        { "ecs.util", luaopen_ecs_util},
        { "fastio", luaopen_fastio},
        { "render.material.arena",  luaopen_material_arena},
        { "render.material.core",   luaopen_material_core},
        { "render.render_material", luaopen_render_material},
        { "render.queue",           luaopen_render_queue},
        { "render.mesh",           luaopen_render_mesh},
        { "system.render",      luaopen_system_render},
        { "render.cache",        luaopen_render_cache},
        { "entity.drawer",      luaopen_entity_drawer},
        { "motion.sampler",     luaopen_motion_sampler},
        { "motion.tween",       luaopen_motion_tween},
        { "image", luaopen_image },
        { "imgui", luaopen_imgui },
        { "imgui.backend", luaopen_imgui_backend },
        { "imgui.internal", luaopen_imgui_internal },
        { "imgui.widgets", luaopen_imgui_widgets },
        { "cell.core", luaopen_cell_core },
        { "firmware", luaopen_firmware },
        { "system.scene", luaopen_system_scene },
        { "cull.core", luaopen_system_cull},
        { "zip", luaopen_zip },
#if !BX_PLATFORM_IOS && !BX_PLATFORM_ANDROID
        { "ozz.offline", luaopen_ozz_offline },
        { "bee.filewatch", luaopen_bee_filewatch },
        { "bee.subprocess", luaopen_bee_subprocess },
#if !BX_PLATFORM_LINUX
        { "filedialog", luaopen_filedialog },
#endif
#endif
        { "window", luaopen_window },
        { "font.util", luaopen_font_util },
#if !BX_PLATFORM_LINUX
        { "httpc", luaopen_httpc },
#endif
#if BX_PLATFORM_IOS
        { "ios", luaopen_ios },
        { "window.ios", luaopen_window_ios },
#endif
#if BX_PLATFORM_ANDROID
        { "android", luaopen_android },
#endif
#if BX_PLATFORM_WINDOWS
        { "bee.windows", luaopen_bee_windows },
#endif
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
