#include "pch.h"
#include "context.h"
#include "lua2struct.h"

#include "lua.hpp"

LUA2STRUCT(struct RmlContext, font_mgr, shader, default_tex, font_tex, viewid, viewrect, layout, bootstrap);
LUA2STRUCT(struct texture_desc, width, height, texid);
LUA2STRUCT(struct shader, font, font_outline, font_shadow, image, font_cr, font_outline_cr, font_shadow_cr, image_cr, debug_draw);
LUA2STRUCT(struct shader_info, prog, uniforms);
LUA2STRUCT(struct shader_info::uniforms, handle, name);
LUA2STRUCT(struct Rect, x, y, w, h);

RmlContext::RmlContext(lua_State *L, int idx){
    lua_struct::unpack(L, idx, *this);
}
