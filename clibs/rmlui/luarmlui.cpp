#include "pch.h"
#define LUA_LIB 1
#include "lua.hpp"
#include "render.h"
#include "file.h"
#include "font.h"
#include "system.h"
#include "context.h"
#include "luabind.h"

#include <bgfx/bgfx_interface.h>
#include <bgfx/luabgfx.h>
#include <bgfx/c99/bgfx.h>

#include <RmlUi/Core.h>
#include <RmlUi/Debugger.h>

#include <cassert>
#include <cstring>

struct RmlInterface {
    SystemInterface system;
    FontEngine      font;
    File            file;
    Renderer        renderer;
    RmlInterface(RmlContext* context)
        : system()
        , font(context)
        , file(context)
        , renderer(context)
    {
        Rml::SetSystemInterface(&system);
        Rml::SetFontEngineInterface(&font);
        Rml::SetFileInterface(&file);
        Rml::SetRenderInterface(&renderer);
    }
};

struct RmlWrapper {
    RmlContext   context;
    RmlInterface interface;
    RmlWrapper(lua_State* L, int idx)
        : context(L, idx)
        , interface(&context)
	{}
};

static RmlWrapper* g_wrapper = nullptr;

static int
lrmlui_init(lua_State *L){
    if (g_wrapper) {
        return luaL_error(L, "RmlUi has been initialized.");
    }
    g_wrapper = new RmlWrapper(L, 1);
    if (!Rml::Initialise()){
        return luaL_error(L, "Failed to Initialise RmlUi.");
    }
    g_wrapper->interface.font.RegisterFontEffectInstancer();
    g_wrapper->context.plugin = lua_plugin_create(L, 2);
    Rml::RegisterPlugin((Rml::Plugin*)g_wrapper->context.plugin);
    return 0;
}

static int
lrmlui_shutdown(lua_State* L) {
    Rml::Shutdown();
    if (g_wrapper) {
        delete g_wrapper;
        g_wrapper = nullptr;
    }
    return 0;
}

static int
lrmlui_call(lua_State* L) {
    if (!g_wrapper) {
        return 0;
    }
    plugin_t plugin = g_wrapper->context.plugin;
    const char* name = luaL_checkstring(L, 1);
    int top = lua_gettop(L);
    if (top == 1) {
        luabind::invoke(lua_plugin_getlua(plugin), [&](lua_State* L) {
            lua_plugin_call(plugin, name, 0);
        });
        return 0;
    }
    std::vector<Rml::Variant> args((size_t)(lua_gettop(L)-1));
    for (size_t i = 0; 0 < args.size(); ++i) {
        lua_getvariant(L, (int)i + 2, &args[i]);
    }
    luabind::invoke(lua_plugin_getlua(plugin), [&](lua_State* L) {
        for (auto const& arg : args) {
            lua_pushvariant(L, arg);
        }
        lua_plugin_call(plugin, name, args.size());
    });
    return 0;
}

static int
lrmlui_frame(lua_State *L){
    if (g_wrapper){
        g_wrapper->interface.renderer.Frame();
    }
    return 0;
}

static int
lrmlui_begin(lua_State *L){
    if (g_wrapper){
        g_wrapper->interface.renderer.Begin();
    }
    return 0;
}

extern "C" {
LUAMOD_API int
luaopen_rmlui(lua_State* L) {
    init_interface(L);
    luaL_Reg l[] = {
        { "init",       lrmlui_init },
        { "shutdown",   lrmlui_shutdown },
        { "begin",      lrmlui_begin },
        { "call",       lrmlui_call },
        { "frame",      lrmlui_frame },
        { nullptr, nullptr },
    };
    luaL_newlib(L, l);
    return 1;
}
}

bgfx_interface_vtbl_t* 
get_bgfx_interface(){
    return bgfx_inf_;
}
