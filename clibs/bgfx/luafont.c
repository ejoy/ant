#define LUA_LIB

#include <lua.h>
#include <lauxlib.h>
#include <bgfx/c99/bgfx.h>

#include "bgfx_interface.h"
#include "luabgfx.h"
#include "font_manager.h"

#include "transient_buffer.h"

struct font_context {
    struct font_manager fm;
};

struct quad_text{
    int16_t p[2];
    int16_t u, v;
    uint32_t color;
};

static struct font_context* new_font_context(lua_State *L){
    struct font_context* t = lua_newuserdatauv(L, sizeof(*t), 0);
    font_manager_init(&t->fm);
    return t;
}

static struct font_manager* 
getF(lua_State *L){
    struct font_context * t = (struct font_context*)lua_touserdata(L, lua_upvalueindex(1));
	return &t->fm;
}

typedef unsigned int utfint;
const char *utf8_decode (const char *s, utfint *val, int strict);

static void
prepare_char(struct font_manager *F, bgfx_texture_handle_t texid, int fontid, int codepoint, int *advance_x, int *advance_y) {
	struct font_glyph g;
	int ret = font_manager_touch(F, fontid, codepoint, &g);
	*advance_x = g.advance_x;
	*advance_y = g.advance_y;

	if (ret < 0) {	// failed
		// todo: report overflow
		return;
	}

	if (ret == 0) {
		// update texture
		const bgfx_memory_t * mem = BGFX(alloc)(g.w * g.h);
		const char * err = font_manager_update(F, fontid, codepoint, &g, mem->data);
		if (err) {
			// todo: report error
			return;
		}
		BGFX(update_texture_2d)(texid, 0, 0, g.u, g.v, g.w, g.h, mem, g.w);
	}
}


static int
lprepare_text(lua_State *L) {
    struct font_manager *F = getF(L);
	uint16_t texture_id = BGFX_LUAHANDLE_ID(TEXTURE, luaL_checkinteger(L, 1));
	bgfx_texture_handle_t th = {texture_id};
	size_t sz;
	const char * str = luaL_checklstring(L, 2, &sz);
	const char * end_ptr = str + sz;

    const int size = luaL_checkinteger(L, 3);
	int fontid = luaL_optinteger(L, 4, 0);

	int advance_x=0, advance_y=0;
    int numchar=0;
	while (str < end_ptr) {
		utfint codepoint;
		str = utf8_decode(str, &codepoint, 1);
		if (str) {
			int x,y;
			prepare_char(F, th, fontid, codepoint, &x, &y);
			advance_x += x;
			if (y > advance_y) {
				advance_y = y;
			}
			++numchar;
		} else {
			return luaL_error(L, "Invalid utf8 text");
		}
	}

    struct font_glyph t_g = {0};
    t_g.advance_x = advance_x;
    t_g.advance_y = advance_y;
    font_manager_scale(F, &t_g, size);

    lua_pushinteger(L, t_g.advance_x);
    lua_pushinteger(L, t_g.advance_y);
    lua_pushinteger(L, numchar);
	return 3;
}

#define FIXPOINT 8

static inline void
fill_text_quad(struct font_manager *F, struct quad_text * qt, int16_t x0, int16_t y0, uint32_t color, int size, struct font_glyph *g) {
	unsigned short w = g->w;
	unsigned short h = g->h;
//	printf("fill %d %d %d %d %d\n", x0, g->u, g->v, w, h);
	font_manager_scale(F, g, size);

	x0 += g->offset_x * FIXPOINT;
	y0 += g->offset_y * FIXPOINT;

	int16_t x1 = x0 + g->w * FIXPOINT;
	int16_t y1 = y0 + g->h * FIXPOINT;

	int16_t u0 = g->u * (0x8000 / FONT_MANAGER_TEXSIZE);
	int16_t v0 = g->v * (0x8000 / FONT_MANAGER_TEXSIZE);

	int16_t u1 = (g->u + w) * (0x8000 / FONT_MANAGER_TEXSIZE);
	int16_t v1 = (g->v + h) * (0x8000 / FONT_MANAGER_TEXSIZE);

	qt[0].p[0] = x0;
	qt[0].p[1] = y0;
	qt[1].p[0] = x1;
	qt[1].p[1] = y0;
	qt[2].p[0] = x0;
	qt[2].p[1] = y1;
	qt[3].p[0] = x1;
	qt[3].p[1] = y1;
	
	qt[0].u = u0;
	qt[0].v = v0;
	qt[1].u = u1;
	qt[1].v = v0;
	qt[2].u = u0;
	qt[2].v = v1;
	qt[3].u = u1;
	qt[3].v = v1;

    for (int ii=0; ii<4; ++ii){
        qt[ii].color = color;
    }
}

static inline int16_t
read_fixpoint(lua_State *L, int idx) {
	if (lua_isinteger(L, idx)) {
		return lua_tointeger(L, idx) * FIXPOINT;
	} else {
		float x = luaL_checknumber(L, idx);
		return (int16_t)(x * FIXPOINT);
	}
}

static int
lload_text_quad(lua_State *L){
    struct font_manager *fm = getF(L);

    struct transient_buffer *tb = luaL_checkudata(L, 1, "BGFX_TB");
    size_t sz;
    const char* text = luaL_checklstring(L, 2, &sz);
    const char* textend = text + sz;

    int16_t x = read_fixpoint(L, 3);
    int16_t y = read_fixpoint(L, 4);

    const int size = (int)luaL_checkinteger(L, 5);
    const uint32_t color = (uint32_t)luaL_checkinteger(L, 6);
    const int fontid = luaL_optinteger(L, 7, 0);

    struct font_glyph g = {0};

    struct quad_text *qt = (struct quad_text *)tb->tvb.data;
    int numchar=0;
    while (text != textend){
        utfint codepoint;
        text = utf8_decode(text, &codepoint, 0);
        if (codepoint){
            if (font_manager_touch(fm, fontid, codepoint, &g) <= 0){
                luaL_error(L, "codepoint:%d, %s, is not cache, need call 'prepare_text' first", codepoint, text);
            }

            if (numchar * 4 > tb->cap_v){
                luaL_error(L, "transient vertex buffer is not enough: %d", tb->cap_v);
            }

            fill_text_quad(fm, qt, x, y, color, size, &g);
            x += g.advance_x;
            ++qt;
            ++numchar;
        }
    }
    return 0;
}

static inline const void *
getttf(lua_State *L, int idx) {
	int type = lua_type(L, idx);
	const char * ttf = NULL;
	if (type == LUA_TSTRING) {
		ttf = lua_tostring(L, idx);
	} else if (type == LUA_TUSERDATA) {
		ttf = (const char *)lua_touserdata(L, idx);
		ttf += 4;	// skip length
	} else {
		luaL_error(L, "Need ttf pointer");
	}
	return (const void *)ttf;
}

static int
laddfont(lua_State *L) {
	struct font_manager *F = getF(L);
	const void * ttf = getttf(L, 1);
	int fontid = font_manager_addfont(F, ttf);
	if (fontid < 0)
		return luaL_error(L, "Add font failed");
	lua_pushinteger(L, fontid);
	return 1;
}

static int
lrebindfont(lua_State *L) {
	struct font_manager *F = getF(L);
	int fontid = luaL_checkinteger(L, 1);
	const void * ttf = getttf(L, 2);
	fontid = font_manager_rebindfont(F, fontid, ttf);
	if (fontid < 0)
		return luaL_error(L, "rebind font failed");
	return 0;
}

static int
lfontheight(lua_State *L) {
	struct font_manager *F = getF(L);
	int size = luaL_checkinteger(L, 1);
	int fontid = luaL_optinteger(L, 2, 0);
	int ascent, descent, lineGap;
	font_manager_fontheight(F, fontid, size, &ascent, &descent, &lineGap);
	lua_pushinteger(L, ascent);
	lua_pushinteger(L, descent);
	lua_pushinteger(L, lineGap);

	return 3;
}


LUAMOD_API int
luaopen_bgfx_font(lua_State *L) {
	luaL_checkversion(L);
	init_interface(L);

	luaL_Reg l[] = {
		{ "fonttexture_size", NULL },
		{ "fontheight", 	lfontheight },
		{ "addfont", 		laddfont },
		{ "rebind", 		lrebindfont },
        { "prepare_text",   lprepare_text},
        { "load_text_quad", lload_text_quad},
		{ NULL, 			NULL },
	};
	luaL_newlibtable(L, l);
	struct font_context * c = new_font_context(L);
	luaL_setfuncs(L, l, 1);
	lua_pushinteger(L, FONT_MANAGER_TEXSIZE);
	lua_setfield(L, -2, "fonttexture_size");

	return 1;
}