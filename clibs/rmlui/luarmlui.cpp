#include "pch.h"
#define LUA_LIB 1
#include "lua.hpp"
#include "render.h"
#include "file.h"
#include "font.h"
#include "system.h"
#include "context.h"
#include "luaplugin.h"

#include <bgfx/bgfx_interface.h>
#include <bgfx/luabgfx.h>
#include <bgfx/c99/bgfx.h>

#include <RmlUi/Core.h>
#include <RmlUi/Debugger.h>

#include <cassert>
#include <cstring>

#define RMLCONTEXT "RMLCONTEXT"

struct rml_context_wrapper {
    rml_context    context;
    System         system;
    FontInterface  font;
    FileInterface2 file;
    Renderer       renderer;
    plugin_t       plugin;
    bool           debugger;
    rml_context_wrapper(lua_State* L, int idx)
        : context(L, idx)
        , system()
        , font(&context)
        , file(&context)
        , renderer(&context)
        , plugin(nullptr)
		, debugger(false)
		{}
    ~rml_context_wrapper() {
        lua_plugin_destroy(plugin);
    }
};

static rml_context_wrapper* g_wrapper = nullptr;

static int
lrmlui_init(lua_State *L){
    if (g_wrapper) {
        return luaL_error(L, "RmlUi has been initialized.");
    }
    g_wrapper = new rml_context_wrapper(L, 1);
    Rml::SetSystemInterface(&g_wrapper->system);
    Rml::SetFontEngineInterface(&g_wrapper->font);
    Rml::SetFileInterface(&g_wrapper->file);
    Rml::SetRenderInterface(&g_wrapper->renderer);
    if (!Rml::Initialise()){
        return luaL_error(L, "Failed to Initialise RmlUi.");
    }
    g_wrapper->font.RegisterFontEffectInstancer();
    g_wrapper->plugin = lua_plugin_create(L, 2);
    Rml::RegisterPlugin((Rml::Plugin*)g_wrapper->plugin);
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
lrmlui_preload_file(lua_State* L) {
    if (!g_wrapper) {
        return 0;
    }
    auto& dict = g_wrapper->context.file_dict;
    luaL_checktype(L, 1, LUA_TTABLE);
    lua_pushnil(L);
    while (lua_next(L, 1)) {
        size_t ksz = 0, vsz = 0;
        const char* k = luaL_checklstring(L, -2, &ksz);
        const char* v = luaL_checklstring(L, -1, &vsz);
        dict.emplace(std::string(k, ksz), std::string(v, vsz));
        lua_pop(L, 1);
    }
    return 0;
}
static int
lrmlui_update(lua_State* L) {
    if (g_wrapper) {
        lua_plugin_call(g_wrapper->plugin, "OnUpdate");
    }
    return 0;
}

static int
lrmlui_frame(lua_State *L){
    if (g_wrapper){
        g_wrapper->renderer.Frame();
    }
    return 0;
}

static int
lrmlui_begin(lua_State *L){
    if (g_wrapper){
        g_wrapper->renderer.Begin();
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
        { "preload_file", lrmlui_preload_file },
        { "update",     lrmlui_update},
        { "begin",      lrmlui_begin},
        { "frame",      lrmlui_frame},
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