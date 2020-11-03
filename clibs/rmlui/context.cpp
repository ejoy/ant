#include "pch.h"
#include "context.h"
#include "lua2struct.h"

#include "lua.hpp"

LUA2STRUCT(struct rml_context, font_mgr, shader, default_tex, font_tex, viewid, viewrect, layout);
LUA2STRUCT(struct texture_desc, width, height, texid);
LUA2STRUCT(struct shader, font_mask, font_range, font, font_outline, font_shadow, font_glow, image);
LUA2STRUCT(struct shader_info, prog, uniforms);
LUA2STRUCT(struct shader_info::uniforms, handle, name);
LUA2STRUCT(struct Rect, x, y, w, h);
LUA2STRUCT(Rml::Vector2i, x, y);

rml_context::rml_context(lua_State *L, int idx){
    lua_struct::unpack(L, idx, *this);
}
