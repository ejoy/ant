#define LUA_LIB 1
#include "lua.hpp"
#include "render.h"
#include "file.h"
#include "font.h"
#include "system.h"
#include "lua2struct.h"

#include <bgfx/bgfx_interface.h>
#include <bgfx/luabgfx.h>
#include <bgfx/c99/bgfx.h>

#include <RmlUi/Core.h>
#include <RmlUi/Debugger.h>
#include <RmlUi/Lua.h>

#include <cassert>
#include <cstring>

struct rml_context {
    FileInterface2  *ifile;
    FontInterface   *ifont;
    Renderer        *irenderer;
    System          *isystem;
    struct context {
        Rml::Context *  handle;
        char            name[32] = "main";
    };
    context         context;
};

struct texture_desc{
    int width, height;
    uint32_t texid;
};

struct rml_init_context {
    struct font {
        texture_desc font_texture;
        struct font_manager* font_mgr;
    };
    struct shader {
        struct shader_info {
            struct uniforms {
                uint32_t handle;
                const char* name;
            };
            uint32_t prog;
            std::vector<uniforms> uniforms;
        };
        shader_info font;
        shader_info font_outline;
        shader_info font_shadow;
        shader_info font_glow;
        shader_info image;
    };
    font        font;
    shader      shader;
    FileDist    file_dist;
    texture_desc default_tex;
    uint16_t    viewid;
    Rect        viewrect;
    bgfx_vertex_layout_t* layout;
};
LUA2STRUCT(struct rml_init_context, font, shader, file_dist, default_tex, viewid, viewrect, layout);
LUA2STRUCT(struct rml_init_context::font, font_texture, font_mgr);
LUA2STRUCT(struct texture_desc, width, height, texid);
LUA2STRUCT(struct rml_init_context::shader, font, font_outline, font_shadow, font_glow, image);
LUA2STRUCT(struct rml_init_context::shader::shader_info, prog, uniforms);
LUA2STRUCT(struct rml_init_context::shader::shader_info::uniforms, handle, name);
LUA2STRUCT(struct Rect, x, y, w, h);

static inline rml_context*
get_rc(lua_State *L, int index = 1){
    return (rml_context*)luaL_checkudata(L, 1, "RML_CONTEXT");
}

static inline Rml::Context*
get_context_handle(lua_State *L, int index=1){
    return get_rc(L, index)->context.handle;
}

static int
lrmlui_context_shutdown(lua_State *L){
    auto rc = get_rc(L);
    Rml::Shutdown();
    auto release = [](auto &p){ 
        if (p){
            delete p; p = nullptr;
        }
    };

    release(rc->ifile);
    release(rc->ifont);
    release(rc->isystem);
    release(rc->irenderer);
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
    auto rc = get_rc(L);
    if (rc->irenderer || rc->isystem || rc->ifont || rc->ifile){
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
lrmlui_context_render(lua_State *L){
    auto context = get_context_handle(L);
    if (!context){
        return luaL_error(L, "invalid context");
    }
    context->Update();
    context->Render();
    return 0;
}

static inline rml_context*
create_rml_context(lua_State *L){
    rml_context* rc = (rml_context*)lua_newuserdatauv(L, sizeof(*rc), 0);
    memset(rc, 0, sizeof(*rc));
    if (luaL_newmetatable(L, "RML_CONTEXT")){
        lua_pushvalue(L, -1);
        lua_setfield(L, -2, "__index");
        luaL_Reg l[] = {
            {"load",        lrmlui_context_load},
            {"render",      lrmlui_context_render},
            {"shutdown",    lrmlui_context_shutdown},
            {"touch_move",  lrmlui_context_touch_move},
            {"touch_down",  lrmlui_context_touch_down},
            {"touch_up",    lrmlui_context_touch_up},
            {"__gc",        lrmlui_context_del},
            {nullptr, nullptr},
        };
		luaL_setfuncs(L, l, 0);
    }
    lua_setmetatable(L, -2);
    return rc;
}

static inline void
init_shader_context(lua_State *L, Renderer *renderer, const rml_init_context& init){
    auto &sc = renderer->GetShaderContext();
    sc.font.prog            = BGFX_LUAHANDLE_ID(PROGRAM, init.shader.font.prog);
    auto find_uniform_handle = [](const auto &uniforms, const char*name){
        for(auto it : uniforms){
            if (strcmp(it.name, name) == 0){
                return it.handle;
            }
        }
        return (uint32_t)UINT16_MAX;
    };
    sc.font.tex_uniform_idx = BGFX_LUAHANDLE_ID(UNIFORM, find_uniform_handle(init.shader.font.uniforms, "s_tex"));
    sc.font.texid           = BGFX_LUAHANDLE_ID(TEXTURE, init.font.font_texture.texid);
    const uint32_t color_uniformidx = find_uniform_handle(init.shader.font.uniforms, "u_mask");
    if (color_uniformidx != UINT16_MAX){
        sc.font.mask_uniform_idx = BGFX_LUAHANDLE_ID(UNIFORM, color_uniformidx);
        sc.font.mask.colormask      = 0.68f;
        sc.font.mask.colorrange     = 0.18f;
    } else {
        luaL_error(L, "font shader need define 'u_mask'");
    }

    const uint32_t effect_uniformidx = find_uniform_handle(init.shader.font.uniforms, "u_effect_color");
    if (effect_uniformidx != UINT16_MAX){
        sc.font.effectcolor_uniform_idx = BGFX_LUAHANDLE_ID(UNIFORM, effect_uniformidx);
        sc.font.effecttype      = FE_Outline;
        sc.font.mask.effectmask = 0.7f;
        sc.font.mask.effectrange= 0.15f;
        sc.font.effectcolor[0]  = 1.0f;
        sc.font.effectcolor[1]  = 0.0f;
        sc.font.effectcolor[2]  = 0.0f;
        sc.font.effectcolor[3]  = 1.0f;
    } else {
        sc.font.effectcolor_uniform_idx = UINT16_MAX;
        sc.font.effecttype      = FE_None;
        sc.font.mask.effectmask = 0.f;
        sc.font.mask.effectrange= 0.f;
    }

    sc.image.prog           = BGFX_LUAHANDLE_ID(PROGRAM, init.shader.image.prog);
    sc.image.tex_uniform_idx= BGFX_LUAHANDLE_ID(UNIFORM, find_uniform_handle(init.shader.image.uniforms, "s_tex"));
}

static int
linit(lua_State *L){
    rml_init_context init;
    lua_struct::unpack(L, init);

    rml_context* rc = create_rml_context(L);
    rc->isystem   = new System();
    rc->ifont     = new FontInterface(init.font.font_mgr);
    rc->ifile     = new FileInterface2(std::move(init.file_dist));
    rc->irenderer = new Renderer(
        init.viewid,
        init.layout,
        init.viewrect
    );
    uint16_t texid = BGFX_LUAHANDLE_ID(TEXTURE, init.font.font_texture.texid);
    rc->irenderer->AddTextureId(
        FontInterface::FONT_TEX_NAME,
        texid,
        Rml::Vector2i(init.font.font_texture.width, init.font.font_texture.height)
    );

    rc->irenderer->AddTextureId(Renderer::DEFAULT_TEX_NAME, init.default_tex.texid, Rml::Vector2i(init.default_tex.width, init.default_tex.height));

    init_shader_context(L, rc->irenderer, init);

    Rml::SetFileInterface(rc->ifile);
    Rml::SetRenderInterface(rc->irenderer);
    Rml::SetSystemInterface(rc->isystem);
    Rml::SetFontEngineInterface(rc->ifont);

    if (!Rml::Initialise()){
        luaL_error(L, "Failed to Initialise Rml");
    }

    Rml::Lua::Initialise();
    rc->ifont->InitFontTex();
    rc->context.handle = Rml::CreateContext(rc->context.name, Rml::Vector2i(init.viewrect.w, init.viewrect.h));
    if (!rc->context.handle){
        luaL_error(L, "Failed to CreateContext:%s, width:%d, height:%d", rc->context.name, init.viewrect.w, init.viewrect.h);
    }
    Rml::Debugger::Initialise(rc->context.handle);
    return 1;
}

extern "C" {
LUAMOD_API int
    luaopen_rmlui(lua_State* L) {
    init_interface(L);
    luaL_Reg l[] = {
        { "init", linit},
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