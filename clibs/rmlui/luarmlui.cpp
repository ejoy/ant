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

struct rml_context_wrapper{
    rml_context *context;
    FileInterface2* ifile;
    FontInterface*  ifont;
    Renderer*       irenderer;
    System*         isystem;
};

static inline rml_context_wrapper*
get_rc_wrapper(lua_State*L, int index = 1){
    return ((rml_context_wrapper*)luaL_checkudata(L, 1, "RML_CONTEXT"));
}

static inline rml_context*
get_rc(lua_State *L, int index = 1){
    return get_rc_wrapper(L, index)->context;
}

static inline Rml::Context*
get_context_handle(lua_State *L, int index=1){
    auto rc = get_rc(L, index);

    return Rml::GetContext(rc->contextname);
}

template<class Ptr>
void release(Ptr &p){ 
    if (p){
        delete p;
        p = nullptr;
    }
};

static int
lrmlui_context_shutdown(lua_State *L){
    auto wrapper = get_rc_wrapper(L);
    Rml::Shutdown();
    release(wrapper->ifile);
    release(wrapper->ifont);
    release(wrapper->isystem);
    release(wrapper->irenderer);
    release(wrapper->context);
    return 0;
}

static int
lrmlui_context_touch_move(lua_State* L) {
    Rml::Context* context = get_context_handle(L);
    context->ProcessMouseMove(luaL_checkinteger(L, 2), luaL_checkinteger(L, 3), 0);
    return 0;
}

static int
lrmlui_context_touch_down(lua_State* L) {
    Rml::Context* context = get_context_handle(L);
    context->ProcessMouseButtonDown(luaL_checkinteger(L, 2), 0);
    return 0;
}

static int
lrmlui_context_touch_up(lua_State* L) {
    Rml::Context* context = get_context_handle(L);
    context->ProcessMouseButtonUp(luaL_checkinteger(L, 2), 0);
    return 0;
}

static int
lrmlui_context_del(lua_State *L){
    auto wrapper = get_rc_wrapper(L);
    if (wrapper->irenderer || 
        wrapper->isystem || 
        wrapper->ifont || 
        wrapper->ifile ||
        wrapper->context){
            luaL_error(L, "RmlUi should call shutdown before lua vm release");
    }
    return 0;
}

static int
lrmlui_context_load(lua_State *L){
    auto context = get_context_handle(L);
    if (!context){
        return luaL_error(L, "invalid context");
    }

    const char* docfile = luaL_checkstring(L, 2);
    auto doc = context->LoadDocument(docfile);
    if (!doc){
        luaL_error(L, "load document failed:%s", docfile);
    }

    doc->Show();
    lua_pushlightuserdata(L, doc);
    return 1;
}


static int
lrmlui_context_create(lua_State *L){
    auto rc = get_rc(L, 1);
    rc->contextname = luaL_checkstring(L, 2);
    rc->contextdim.x = luaL_checkinteger(L, 3);
    rc->contextdim.y = luaL_checkinteger(L, 4);

    auto ctx = Rml::CreateContext(rc->contextname, rc->contextdim);
    if (!ctx){
        luaL_error(L, "Failed to CreateContext:%s, width:%d, height:%d", rc->contextname.c_str(), rc->contextdim.x, rc->contextdim.y);
    }
    Rml::Debugger::Initialise(ctx);
    return 0;
}

static int
lrmlui_context_render(lua_State *L){
    auto context = get_context_handle(L);
    if (!context){
        return luaL_error(L, "invalid context");
    }
    context->Update();
    context->Render();
    return 0;
}

static int
lrmlui_context_debugger(lua_State* L) {
    Rml::Debugger::SetVisible(!Rml::Debugger::IsVisible());
    return 0;
}

static inline rml_context_wrapper*
create_rml_context(lua_State *L){
    rml_context_wrapper* wrapper = (rml_context_wrapper*)lua_newuserdatauv(L, sizeof(*wrapper), 0);
    wrapper->context = new rml_context;
    auto rc = wrapper->context;
    if (luaL_newmetatable(L, "RML_CONTEXT")){
        lua_pushvalue(L, -1);
        lua_setfield(L, -2, "__index");
        luaL_Reg l[] = {
            {"load",        lrmlui_context_load},
            {"create",      lrmlui_context_create},
            {"render",      lrmlui_context_render},
            {"shutdown",    lrmlui_context_shutdown},
            {"touch_move",  lrmlui_context_touch_move},
            {"touch_down",  lrmlui_context_touch_down},
            {"touch_up",    lrmlui_context_touch_up},
            {"debugger",    lrmlui_context_debugger},
            {"__gc",        lrmlui_context_del},
            {nullptr, nullptr},
        };
		luaL_setfuncs(L, l, 0);
    }
    lua_setmetatable(L, -2);
    return wrapper;
}

static int
linit(lua_State *L){
    auto wrapper = create_rml_context(L);
    auto rc = wrapper->context;
    lua_pushvalue(L, 1);
    rc->unpack(L);
    lua_pop(L, 1);
    wrapper->isystem   = new System();
    wrapper->ifont     = new FontInterface(rc->font_mgr);
    wrapper->ifile     = new FileInterface2(rc);
    wrapper->irenderer = new Renderer(rc);

    Rml::SetFileInterface(wrapper->ifile);
    Rml::SetRenderInterface(wrapper->irenderer);
    Rml::SetSystemInterface(wrapper->isystem);
    Rml::SetFontEngineInterface(wrapper->ifont);

    if (!Rml::Initialise()){
        luaL_error(L, "Failed to Initialise Rml");
    }

    Rml::Lua::Initialise();
    wrapper->ifont->InitFontTex();
    return 1;
}

extern "C" {
LUAMOD_API int
    luaopen_rmlui(lua_State* L) {
    init_interface(L);
    luaL_Reg l[] = {
        { "init",           linit},
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