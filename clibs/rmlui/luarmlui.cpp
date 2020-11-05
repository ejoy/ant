#include "pch.h"
#define LUA_LIB 1
#include "lua.hpp"
#include "render.h"
#include "file.h"
#include "font.h"
#include "system.h"
#include "context.h"

#include <bgfx/bgfx_interface.h>
#include <bgfx/luabgfx.h>
#include <bgfx/c99/bgfx.h>

#include <RmlUi/Core.h>
#include <RmlUi/Debugger.h>
#include <RmlUi/Lua.h>

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
	lua_State *L;
	size_t mem;
	int warnstate;
};

static void *
rml_alloc(void *ud, void *ptr, size_t osize, size_t nsize) {
	struct rcontext *ctx = (struct rcontext *)ud;
	if (nsize == 0) {
		ctx->mem -= osize;
		free(ptr);
		return NULL;
	}
	else if (ptr == NULL) {
		ctx->mem += nsize;
		return malloc(nsize);
	} else {
		ctx->mem -= osize;
		ctx->mem += nsize;
		return realloc(ptr, nsize);
	}
}

static int
rml_panic (lua_State *L) {
	const char *msg = lua_tostring(L, -1);
	if (msg == NULL) msg = "error object is not a string";
	lua_writestringerror("PANIC: unprotected error in call to Lua API (%s)\n",
						msg);
	return 0;
}

/*
** Emit a warning. '*warnstate' means:
** 0 - warning system is off;
** 1 - ready to start a new message;
** 2 - previous message is to be continued.
*/
static void
rml_warnf (void *ud, const char *message, int tocont) {
	struct rcontext *ctx = (struct rcontext *)ud;
	int *warnstate = &ctx->warnstate;
	if (*warnstate != 2 && !tocont && *message == '@') {  /* control message? */
		if (strcmp(message, "@off") == 0)
			*warnstate = 0;
		else if (strcmp(message, "@on") == 0)
			*warnstate = 1;
		return;
	}
	else if (*warnstate == 0)  /* warnings off? */
		return;
	if (*warnstate == 1)  /* previous message was the last? */
		lua_writestringerror("%s", "Lua warning: ");  /* start a new warning */
	lua_writestringerror("%s", message);  /* write message */
	if (tocont)  /* not the last part? */
		*warnstate = 2;  /* to be continued */
	else {  /* last part */
		lua_writestringerror("%s", "\n");  /* finish message with end-of-line */
		*warnstate = 1;  /* ready to start a new message */
	}
}

static int
init_luavm(struct rcontext *R) {
	R->mem = 0;
	R->warnstate = 0;
	lua_State *L = lua_newstate(rml_alloc, R);
	if (L == NULL)
		return 0;
	lua_atpanic(L, &rml_panic);
	lua_setwarnf(L, rml_warnf, R);
	R->L = L;
	// todo : init libs
	return 1;
}

static int
lrelease_context(lua_State *L) {
	struct rcontext *R = (struct rcontext *)lua_touserdata(L, 1);
	if (R->ctx == NULL)
		return 0;
	Rml::RemoveContext(R->ctx->GetName());
	R->ctx = NULL;
	return 0;
}

static int
lctx_Memory(lua_State *L) {
	struct rcontext *R = (struct rcontext *)lua_touserdata(L, 1);
	lua_pushinteger(L, R->mem);
	return 1;
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
	if (!init_luavm(R)) {
		return luaL_error(L, "Init context VM failed");
	}
	if (luaL_newmetatable(L, RMLCONTEXT)) {
		luaL_Reg lib[] = {
			{ "__gc", lrelease_context },
			{ "__index", NULL },
			{ "LoadDocument", lctx_load_document },
			{ "Update", lctx_update },
			{ "Render", lctx_render },
			{ "Memory", lctx_Memory },
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