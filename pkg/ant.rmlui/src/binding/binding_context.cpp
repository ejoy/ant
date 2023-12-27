#include <binding/context.h>
#include "lua2struct.h"
#include <lua.hpp>

LUA2STRUCT(struct RmlContext, font_mgr, shader, viewid);
LUA2STRUCT(struct shader, uniforms, font, font_outline, font_shadow, image, font_cr, font_outline_cr, font_shadow_cr, image_cr, image_gray, image_cr_gray);

RmlContext::RmlContext(lua_State *L, int idx) {
    lua_struct::unpack(L, idx, *this);
}
