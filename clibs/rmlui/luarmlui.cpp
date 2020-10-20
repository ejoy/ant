#define LUA_LIB 1
#include "lua.hpp"
#include "render.h"
#include "file.h"
#include "font.h"
#include "system.h"

#include <bgfx/bgfx_interface.h>
#include <bgfx/c99/bgfx.h>

#include <RmlUi/Core.h>

#include <cassert>

//define class HWInterface/////////////////////////////////////////////////////////////
#include "HWInterface.h"

HWInterface::HWInterface(uint16_t viewid, void *layout, const Rect &vr)
    : mViewId(viewid)
    , mLayout(layout)
    , mRenderState(BGFX_STATE_WRITE_RGB|BGFX_STATE_WRITE_A|BGFX_STATE_DEPTH_TEST_ALWAYS|BGFX_STATE_MSAA)
    , mViewRect(vr)
    {
        BGFX(set_view_rect)(mViewId, uint16_t(mViewRect.x), uint16_t(mViewRect.y), uint16_t(mViewRect.w), uint16_t(mViewRect.h));
    }

uint16_t HWInterface::CreateTexture(const uint8_t *data, uint32_t numbytes, SamplerFlag flags, int *w, int *h){
	const bgfx_memory_t *mem = BGFX(alloc)(numbytes);
	memcpy(mem->data, data, numbytes);

	bgfx_texture_info_t info;
	const bgfx_texture_handle_t th = BGFX(create_texture)(mem, flags, 1, &info);
	if (th.idx != UINT16_MAX){
		*w = (int)info.width;
		*h = (int)info.height;
	}
	return th.idx;
}

uint16_t HWInterface::CreateTexture2D(int w, int h, SamplerFlag flags, const uint8_t *data, uint32_t numbytes){
	const bgfx_memory_t *mem = BGFX(alloc)(numbytes);
	memcpy(mem->data, data, numbytes);
	return BGFX(create_texture_2d)(w, h, false, 1, BGFX_TEXTURE_FORMAT_RGBA8, flags, mem).idx;
}

void HWInterface::DestroyTexture(uint16_t texid){
    BGFX(destroy_texture)({texid});
}

void HWInterface::SetScissorRect(const Rect* rect){
    rect = rect ? rect : &mViewRect;
    BGFX(set_view_scissor)(mViewId, rect->x, rect->y, rect->w, rect->h);
}

void HWInterface::SetTransform(const float *m){
    BGFX(set_view_transform)(mViewId, m, nullptr);
}

void HWInterface::Render(Rml::Vertex* vertices, int num_vertices, 
            int* indices, int num_indices, 
            Rml::TextureHandle texture, const float *transform){

    SetTransform(transform);
    bgfx_transient_vertex_buffer_t tvb;
    BGFX(alloc_transient_vertex_buffer)(&tvb, num_vertices, (bgfx_vertex_layout_t*)mLayout);

    memcpy(tvb.data, vertices, num_vertices * sizeof(Rml::Vertex));
    BGFX(set_transient_vertex_buffer)(0, &tvb, 0, num_vertices);

    bgfx_transient_index_buffer_t tib;
    BGFX(alloc_transient_index_buffer)(&tib, num_indices);
    uint16_t *data = (uint16_t*)tib.data;
    for (int ii=0; ii<num_indices; ++ii){
        int d = indices[ii];
        if (d > UINT16_MAX){
            assert(false);
            return;
        }

        *data++ = (uint16_t)d;
    }

    BGFX(set_transient_index_buffer)(&tib, 0, num_indices);
    BGFX(set_state)(mRenderState, 0);

    const uint16_t texid = (uint16_t)texture;
    const auto &si = texid == mShaderContext.font_texid ? mShaderContext.font : mShaderContext.image;
    BGFX(set_texture)(0, {si.tex_uniform_idx}, {texid}, UINT32_MAX);

    BGFX(submit)(mViewId, {si.prog}, 0, BGFX_DISCARD_ALL);
}

//end define class HWInterface/////////////////////////////////////////////////////////

struct rml_context{
    FileInterface2  *ifile;
    FontInterface   *ifont;
    Renderer        *irenderer;
    System          *isystem;
    HWInterface     *hwi;
    struct context {
        Rml::Context *  handle;
        char            name[32];
    };
    context         context;
};

static inline uint16_t
get_field_handle_idx(lua_State *L, int index, const char* fieldname){
    auto handleidx = lua_getfield(L, index, fieldname) == LUA_TNUMBER ? (uint16_t)lua_tointeger(L, -1) : UINT16_MAX;
    lua_pop(L, 1);
    if (handleidx == UINT16_MAX){
        return luaL_error(L, "invalid handle:%s", fieldname);
    }
    return handleidx;
}

static inline void
parse_font(lua_State *L, int index, struct font_manager **fm, uint16_t *texid, Rml::Vector2i *tex_dim){
    struct font_manager* fontmgr = nullptr;
    if (lua_getfield(L, 1, "font") == LUA_TTABLE){
        if (lua_getfield(L, -1, "font_mgr") == LUA_TLIGHTUSERDATA){
            *fm = (struct font_manager*)lua_touserdata(L, -1);
        } else {
            luaL_error(L, "font manager pointer must be provided!");
        }
        lua_pop(L, 1);

        if (lua_getfield(L, -1, "font_texture") == LUA_TTABLE){
            *texid = get_field_handle_idx(L, -1, "texid");

            lua_getfield(L, -1, "width");
            tex_dim->x = (int)lua_tointeger(L, -1);
            lua_pop(L, 1);

            lua_getfield(L, -1, "height");
            tex_dim->y = (int)lua_tointeger(L, -1);
            lua_pop(L, 1);
        } else {
            luaL_error(L, "Invalid font texture info");
        }
        lua_pop(L, 1);
    } else {
        luaL_error(L, "invalid font info");
    }
    lua_pop(L, 1);

}

static inline void
parse_file_dict(lua_State *L, int index, Rml::String &root_dir, FileDist &fd){
    if (lua_getfield(L, 1, "file_dist") == LUA_TTABLE){
        lua_getfield(L, -1, "root_dir");
        root_dir = lua_tostring(L, -1);
        lua_pop(L, 1);

        if (lua_getfield(L, -1, "files") == LUA_TTABLE){
            for(lua_pushnil(L); lua_next(L, -2); lua_pop(L, 2)){
                lua_pushvalue(L, -2);
                const char* key = lua_tostring(L, -1);
                const char* value = lua_tostring(L, -2); 
                fd[key] = value;
            }
        } else {
            luaL_error(L, "file_dist.files is not a table!");
        }
        lua_pop(L, 1);
    } else {
        luaL_error(L, "file dist should provide as [key:local_file_path] pairs table");
    }

    lua_pop(L, 1);
}

static inline void
parse_viewrect(lua_State *L, int index, Rect *rect){
    if (lua_getfield(L, index, "viewrect") == LUA_TTABLE){
        auto get_int = [L](const char *name, int index, int *d){
            if (lua_getfield(L, index, name) == LUA_TNUMBER)
                *d = (int)lua_tointeger(L, -1);
            else 
                luaL_error(L, "invalid '%s' data", name);
            lua_pop(L, 1);
        };

        get_int("x", -1, &rect->x);
        get_int("y", -1, &rect->y);

        get_int("w", -1, &rect->w);
        get_int("h", -1, &rect->h);
    }else {
        luaL_error(L, "invalid viewrect");
    }

    lua_pop(L, 1);
}

static inline void
parse_context_name(lua_State *L, int index, char contextname[32]){
    const char* name = lua_getfield(L, index, "name") == LUA_TSTRING ? lua_tostring(L, -1) : "main";
    lua_pop(L, 1);

    if (strlen(name) >31){
        luaL_error(L, "context name too long, should least than 31 char");
    }

    strcpy(contextname, name);
}

static inline bgfx_vertex_layout_t*
parse_vertex_layout(lua_State *L, int index){
    bgfx_vertex_layout_t* l = nullptr;
    if (lua_getfield(L, index, "layout") == LUA_TUSERDATA){
        l = (bgfx_vertex_layout_t *)lua_touserdata(L, -1);
    } else {
        luaL_error(L, "invalid vertex layout");
    }
    lua_pop(L, 1);
    return l;
}

static inline void
parse_shader_context(lua_State *L, int index, ShaderContext *c){
    if (lua_getfield(L, index, "shader") != LUA_TTABLE){
        luaL_error(L, "invalid shader info");
    }

    auto parse_shader_info = [L](const char*name, ShaderInfo &si){
        if (lua_getfield(L, -1, name) != LUA_TTABLE){
            luaL_error(L, "invalid shader.%s info", name);
        }

        si.prog = get_field_handle_idx(L, -1, "prog");

        //uniform idx
        lua_getfield(L, -1, "uniforms");
        if (lua_rawlen(L, -1) <= 0){
            luaL_error(L, "invalid shader.uniforms, uniform is empty");
        }
        lua_geti(L, -1, 1);
        si.tex_uniform_idx = get_field_handle_idx(L, -1, "handle");
        lua_pop(L, 1);  //"uniforms[1]"
        lua_pop(L, 1);  //"uniforms"
        lua_pop(L, 1); //name
    };

    parse_shader_info("font", c->font);
    parse_shader_info("image", c->image);
    
    lua_pop(L, 1);
}

static inline rml_context*
get_rc(lua_State *L, int index = 1){
    return (rml_context*)luaL_checkudata(L, 1, "RML_CONTEXT");
}

static inline Rml::Context*
get_context_handle(lua_State *L, int index=1){
    return get_rc(L, index)->context.handle;
}

static int
lrmlui_context_del(lua_State *L){
    auto rc = get_rc(L);

    Rml::Shutdown();
    auto release = [](auto &p){ delete p; p = nullptr;};

    release(rc->ifile);
    release(rc->ifont);
    release(rc->isystem);
    release(rc->irenderer);
    release(rc->hwi);

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
lrmlui_context_font(lua_State *L){
    auto rc = get_rc(L, 1);
    const char* filename = luaL_checkstring(L, 2);
    if (!Rml::LoadFontFace(filename)){
        return luaL_error(L, "load font failed:%s", filename);
    }

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

static inline rml_context*
create_rml_context(lua_State *L){
    rml_context* rc = (rml_context*)lua_newuserdatauv(L, sizeof(*rc), 0);
    memset(rc, 0, sizeof(*rc));
    if (luaL_newmetatable(L, "RML_CONTEXT")){
        lua_pushvalue(L, -1);
        lua_setfield(L, -2, "__index");
        luaL_Reg l[] = {
            {"load",    lrmlui_context_load},
            {"load_font",lrmlui_context_font},
            {"render",  lrmlui_context_render},
            {"__gc",    lrmlui_context_del},
            {nullptr, nullptr},
        };
		luaL_setfuncs(L, l, 0);
    }
    lua_setmetatable(L, -2);
    return rc;
}

static int
linit(lua_State *L){
    luaL_checktype(L, 1, LUA_TTABLE);
    rml_context* rc = create_rml_context(L);
    rc->isystem     = new System();

    struct font_manager *fontmgr = nullptr;
    uint16_t texid; Rml::Vector2i tex_dim;
    parse_font(L, 1, &fontmgr, &texid, &tex_dim);
    rc->ifont       = new FontInterface(fontmgr);

    Rml::String root_dir; FileDist fd;
    parse_file_dict(L, 1, root_dir, fd);
    rc->ifile       = new FileInterface2(std::move(root_dir), std::move(fd));

    auto &c = rc->context;
    parse_context_name(L, 1, c.name);
    Rect rt;
    parse_viewrect(L, 1, &rt);
    auto l = parse_vertex_layout(L, 1);
    rc->hwi = new HWInterface(get_field_handle_idx(L, 1, "viewid"), l, rt);

    auto &sc = rc->hwi->GetShaderContext();
    parse_shader_context(L, 1, &sc);
    sc.font_texid = texid;
    rc->irenderer = new Renderer(rc->hwi);
    rc->irenderer->AddTextureId(FontInterface::FONT_TEX_NAME, texid, tex_dim);

    Rml::SetFileInterface(rc->ifile);
    Rml::SetRenderInterface(rc->irenderer);
    Rml::SetSystemInterface(rc->isystem);
    Rml::SetFontEngineInterface(rc->ifont);

    if (!Rml::Initialise()){
        luaL_error(L, "Failed to Initialise Rml");
    }

    c.handle = Rml::CreateContext(c.name, Rml::Vector2i(rt.w, rt.h));
    if (!c.handle){
        luaL_error(L, "Failed to CreateContext:%s, width:%d, height:%d", c.name, rt.w, rt.h);
    }

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