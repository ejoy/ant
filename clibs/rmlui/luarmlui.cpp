#define LUA_LIB 1
#include "lua.hpp"
#include "render.h"
#include "file.h"
#include "font.h"
#include "system.h"

#include <RmlUi/Core.h>

struct rml_context{
    FileInterface2  *ifile;
    FontInterface   *ifont;
    Renderer        *irenderer;
    System          *isystem;
};

static inline HW_Interface
parse_hwi(lua_State *L, int index){
    HW_Interface hwi = {nullptr};
    if (lua_getfield(L, index, "hwi") == LUA_TTABLE){
        if (lua_getfield(L, -1, "create_texture") == LUA_TLIGHTUSERDATA){
            hwi.create_texture = (decltype(hwi.create_texture))lua_touserdata(L, -1);
        } else {
            luaL_error(L, "invalid type for 'create_texture' field, function pointer as light userdata is needed");
        }
        lua_pop(L, 1);

        if (lua_getfield(L, -1, "destory_texture") == LUA_TLIGHTUSERDATA){
            hwi.destory_texture = (decltype(hwi.destory_texture))lua_touserdata(L, -1);
        } else {
            luaL_error(L, "invalid type for 'destory_texture' field, function pointer as light userdata is needed");
        }
        lua_pop(L, 1);

        if (lua_getfield(L, -1, "get_texture_dimension") == LUA_TLIGHTUSERDATA){
            hwi.get_texture_dimension = (decltype(hwi.get_texture_dimension))lua_touserdata(L, -1);
        } else {
            luaL_error(L, "invalid type for 'get_texture_dimension' field, function pointer as light userdata is needed");
        }
        lua_pop(L, 1);
    }
    lua_pop(L, 1);
    return hwi;
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
            lua_getfield(L, -1, "texid");
            *texid = (uint16_t)lua_tointeger(L, -1);
            lua_pop(L, 1);

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

        lua_getfield(L, -1, "files");{
            for(lua_pushnil(L); lua_next(L, index); lua_pop(L, 2)){
                lua_pushvalue(L, -2);
                const char* key = lua_tostring(L, -1);
                const char* value = lua_tostring(L, -2); 
                fd[key] = value;
            }
        }
        lua_pop(L, 1);
    } else {
        luaL_error(L, "file dist should provide as [key:local_file_path] pairs table");
    }

    lua_pop(L, 1);
}

static inline rml_context*
get_rc(lua_State *L, int index = 1){
    return (rml_context*)lua_touserdata(L, 1);
}

static int
lrmlui_context_del(lua_State *L){
    auto rc = get_rc(L);

    Rml::Shutdown();
    delete rc->ifile;
    delete rc->ifont;
    delete rc->isystem;
    delete rc->irenderer;

    return 0;
}

static int
linit(lua_State *L){
    luaL_checktype(L, 1, LUA_TTABLE);
    auto hwi        = parse_hwi(L, 1);
    struct font_manager *fontmgr = nullptr;
    uint16_t texid; Rml::Vector2i tex_dim;
    parse_font(L, 1, &fontmgr, &texid, &tex_dim);

    Rml::String root_dir; FileDist fd;
    parse_file_dict(L, 1, root_dir, fd);

    rml_context* rc = (rml_context*)lua_newuserdatauv(L, sizeof(*rc), 0);

    rc->ifile       = new FileInterface2(std::move(root_dir), std::move(fd));
    rc->isystem     = new System();
    rc->irenderer   = new Renderer(hwi);
    rc->ifont       = new FontInterface(fontmgr);

    rc->irenderer->AddTextureId(FontInterface::FONT_TEX_NAME, texid, tex_dim);

    if (luaL_newmetatable(L, "RML_CONTEXT")){
        lua_pushvalue(L, -1);
        lua_setfield(L, -2, "__index");
        luaL_Reg l[] = {
            // {"update", lrmlui_update},
            // {"render", lrmlui_render},
            {"__gc", lrmlui_context_del},
            {nullptr, nullptr},
        };
		luaL_setfuncs(L, l, 0);
    }

    Rml::SetFileInterface(rc->ifile);
    Rml::SetRenderInterface(rc->irenderer);
    Rml::SetSystemInterface(rc->isystem);
    Rml::SetFontEngineInterface(rc->ifont);

    if (!Rml::Initialise()){
        luaL_error(L, "Failed to Initialise Rml");
    }

    return 1;
}

extern "C" {
LUAMOD_API int
    luaopen_rmlui(lua_State* L) {
    luaL_Reg l[] = {
        { "init", linit},
        { nullptr, nullptr },
    };
    luaL_newlib(L, l);
    return 1;
}
}