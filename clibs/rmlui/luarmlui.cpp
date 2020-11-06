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
    bool           debugger;
    rml_context_wrapper(lua_State* L, int idx)
        : context(L, idx)
        , system()
        , font(&context)
        , file(&context)
        , renderer(&context)
		, debugger(false)
		{}
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

	lua_plugin_register(L, 2);
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
lrmlui_frame(lua_State *L){
    if (g_wrapper){
        g_wrapper->renderer.Frame();
    }
    return 0;
}

// RML Context

struct rcontext {
	Rml::Context* ctx;
};

static int
lrelease_context(lua_State *L) {
	struct rcontext *R = (struct rcontext *)lua_touserdata(L, 1);
	if (R->ctx == NULL)
		return 0;
	Rml::RemoveContext(R->ctx->GetName());
	R->ctx = NULL;
	return 0;
}

static Rml::Context *
get_context(lua_State *L) {
	struct rcontext *R = (struct rcontext *)lua_touserdata(L, 1);
	if (R == NULL || R->ctx == NULL) {
		luaL_error(L, "Invalid Rml Context");
	}
	return R->ctx;
}

static int
lctx_load_document(lua_State *L) {
	const char * path = luaL_checkstring(L, 2);
	Rml::ElementDocument * doc = get_context(L)->LoadDocument(path);
	if (doc == NULL) {
		return 0;
	}
	// todo : gen document ud
	doc->Show();
	lua_pushboolean(L, 1);
	return 1;
}

static int
lctx_update(lua_State *L) {
	get_context(L)->Update();
	return 0;
}

static int
lctx_render(lua_State *L) {
	get_context(L)->Render();
	return 0;
}

static int
lcreate_context(lua_State *L) {
	const char * name = luaL_checkstring(L, 1);
	int w = luaL_checkinteger(L, 2);
	int h = luaL_checkinteger(L, 3);
	struct rcontext * R = (struct rcontext *)lua_newuserdatauv(L, sizeof(*R), 0);
	R->ctx = NULL;
	if (luaL_newmetatable(L, RMLCONTEXT)) {
		luaL_Reg lib[] = {
			{ "__gc", lrelease_context },
			{ "__index", NULL },
			{ "LoadDocument", lctx_load_document },
			{ "Update", lctx_update },
			{ "Render", lctx_render },
			{ NULL, NULL },
		};
		luaL_setfuncs(L, lib, 0);
		lua_pushvalue(L, -1);
		lua_setfield(L, -2, "__index");
	}
	lua_setmetatable(L, -2);
	Rml::Context * ctx = Rml::CreateContext(name, Rml::Vector2i(w,h));
	if (ctx == NULL) {
		return luaL_error(L, "Init Rml context failed");
	}
	R->ctx = ctx;

	return 1;
}

extern "C" {
LUAMOD_API int
luaopen_rmlui(lua_State* L) {
    init_interface(L);
    luaL_Reg l[] = {
        { "init",       lrmlui_init },
        { "shutdown",   lrmlui_shutdown },
        { "preload_file", lrmlui_preload_file },
        { "frame",      lrmlui_frame},

		{ "CreateContext", lcreate_context },
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