#define LUA_LIB

#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
#include "../bgfx/bgfx_interface.h"

#include "font_manager.h"
#include "truetype.h"

#include <string.h>
#include <stdint.h>
#include <stdlib.h>
#include <assert.h>
#include <ctype.h>

struct quad_text{
    int16_t p[2];
    int16_t u, v;
    uint32_t color;
};

static struct font_manager* 
getF(lua_State *L){
    return (struct font_manager*)lua_touserdata(L, lua_upvalueindex(1));
}

/*
** From lua 5.4
** Decode one UTF-8 sequence, returning NULL if byte sequence is
** invalid.  The array 'limits' stores the minimum value for each
** sequence length, to check for overlong representations. Its first
** entry forces an error for non-ascii bytes with no continuation
** bytes (count == 0).
*/
typedef unsigned int utfint;
#define MAXUNICODE	0x10FFFFu
#define MAXUTF		0x7FFFFFFFu

const char *utf8_decode (const char *s, utfint *val, int strict) {
  static const utfint limits[] =
        {~(utfint)0, 0x80, 0x800, 0x10000u, 0x200000u, 0x4000000u};
  unsigned int c = (unsigned char)s[0];
  utfint res = 0;  /* final result */
  if (c < 0x80)  /* ascii? */
    res = c;
  else {
    int count = 0;  /* to count number of continuation bytes */
    for (; c & 0x40; c <<= 1) {  /* while it needs continuation bytes... */
      unsigned int cc = (unsigned char)s[++count];  /* read next byte */
      if ((cc & 0xC0) != 0x80)  /* not a continuation byte? */
        return NULL;  /* invalid byte sequence */
      res = (res << 6) | (cc & 0x3F);  /* add lower 6 bits from cont. byte */
    }
    res |= ((utfint)(c & 0x7F) << (count * 5));  /* add first byte */
    if (count > 5 || res > MAXUTF || res < limits[count])
      return NULL;  /* invalid byte sequence */
    s += count;  /* skip continuation bytes read */
  }
  if (strict) {
    /* check for invalid code points; too large or surrogates */
    if (res > MAXUNICODE || (0xD800u <= res && res <= 0xDFFFu))
      return NULL;
  }
  if (val) *val = res;
  return s + 1;  /* +1 to include first byte */
}

static void
release_char_memory(void *d, void *u){
	free(d);
}

static void
prepare_char(struct font_manager* F, uint16_t texid, int fontid, int codepoint, int *advance_x, int *advance_y) {
	struct font_glyph g;
	int ret = font_manager_touch(F, fontid, codepoint, &g);
	*advance_x = g.advance_x;
	*advance_y = g.advance_y;

	if (ret < 0) {	// failed
		// todo: report overflow
		return;
	}

	if (ret == 0) {
		uint8_t *mem = malloc(g.w * g.h);
		const char * err = font_manager_update(F, fontid, codepoint, &g, mem);
		if (err){
			return ;
		}
		bgfx_texture_handle_t th = { texid };
		const bgfx_memory_t* m = BGFX(make_ref_release)(mem, g.w * g.h, release_char_memory, NULL);
		BGFX(update_texture_2d)(th, 0, 0, g.u, g.v, g.w, g.h, m, g.w);
	}
}

static int
lprepare_text(lua_State *L) {
    struct font_manager *F = (struct font_manager *)lua_touserdata(L, lua_upvalueindex(1));
	uint16_t texid = luaL_checkinteger(L, 1);
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
			prepare_char(F, texid, fontid, codepoint, &x, &y);
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


// static int
// ltext_codepoints(lua_State *L){
// 	size_t sz;
// 	const char * str = luaL_checklstring(L, 1, &sz);
// 	const char * end_ptr = str + sz;

// 	lua_createtable(L, (int)sz, 0);
// 	int idx=0;
// 	while (str < end_ptr) {
// 		utfint codepoint;
// 		str = utf8_decode(str, &codepoint, 1);
// 		if (str){
// 			lua_pushinteger(L, codepoint);
// 			lua_seti(L, -2, ++idx);
// 		} else {
// 			return luaL_error(L, "Invalid utf8 text");
// 		}
// 	}

// 	return 1;
// }

#define FIXPOINT FONT_POSTION_FIX_POINT

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

    struct quad_text *qtdata = (struct quad_text*)lua_touserdata(L, 1);
    size_t sz;
    const char* text = luaL_checklstring(L, 2, &sz);
    const char* textend = text + sz;

    int16_t x = read_fixpoint(L, 3);
    int16_t y = read_fixpoint(L, 4);

    const int fontsize = (int)luaL_checkinteger(L, 5);
    const uint32_t color = (uint32_t)luaL_checkinteger(L, 6);
    const int fontid = luaL_optinteger(L, 7, 0);

	struct quad_text *qt = qtdata;

    struct font_glyph g = {0};
    while (text != textend){
        utfint codepoint;
        text = utf8_decode(text, &codepoint, 0);
        if (codepoint){
            if (font_manager_touch(fm, fontid, codepoint, &g) <= 0){
                luaL_error(L, "codepoint:%d, %s, is not cache, need call 'prepare_text' first", codepoint, text);
            }

            fill_text_quad(fm, qt, x, y, color, fontsize, &g);
            x += g.advance_x * FIXPOINT;
            qt += 4;
        }
    }
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

static int
lsubmit(lua_State *L){
	struct font_manager *F = getF(L);
	font_manager_flush(F);
	return 0;
}

static int
limport(lua_State *L) {
	struct font_manager *F = getF(L);
	const char* fontpath = luaL_checkstring(L, 1);
	font_manager_import(F, fontpath);
	return 0;
}

static int
lname(lua_State *L) {
	struct font_manager *F = getF(L);
	const char* family = luaL_checkstring(L, 1);
	const int fontid = font_manager_addfont_with_family(F, family);
	if (fontid > 0){
		lua_pushinteger(L, fontid);
		return 1;
	}
	return 0;
}

static int
initfont(lua_State *L) {
	luaL_checktype(L, 2, LUA_TLIGHTUSERDATA);
	luaL_Reg l[] = {
		{ "import",				limport },
		{ "name",				lname },
		{ "fontheight",			lfontheight },
		{ "prepare_text",		lprepare_text },
		{ "load_text_quad",		lload_text_quad },
		{ "submit",				lsubmit },
		{ NULL, 				NULL },
	};
	lua_settop(L, 2);
	lua_pushinteger(L, FONT_MANAGER_TEXSIZE);
	lua_setfield(L, 1, "fonttexture_size");
	lua_pushvalue(L, 2);
	lua_setfield(L, 1, "font_manager");
	luaL_setfuncs(L, l, 1);
	lua_settop(L, 1);
	return 1;
}

LUAMOD_API int
luaopen_font(lua_State *L) {
	luaL_checkversion(L);
	lua_newtable(L);
	lua_newtable(L);
	lua_pushcfunction(L, initfont);
	lua_setfield(L, -2, "__call");
	lua_setmetatable(L, -2);
	return 1;
}

static int
luavm_init(lua_State *L) {
	luaL_openlibs(L);
	const char* boot = (const char*)lua_touserdata(L, 1);
	if (luaL_loadstring(L, boot) != LUA_OK) {
		return lua_error(L);
	}
	lua_call(L, 0, 0);
	return 0;
}

static lua_State*
luavm_create(lua_State *L, const char* boot) {
	lua_State* vL = luaL_newstate();
	if (!vL) {
		luaL_error(L, "not enough memory");
		return NULL;
	}
	lua_pushcfunction(vL, luavm_init);
	lua_pushlightuserdata(vL, (void*)boot);
	if (lua_pcall(vL, 1, 0, 0) != LUA_OK) {
		lua_pushstring(L, lua_tostring(vL, -1));
		lua_close(vL);
		lua_error(L);
		return NULL;
	}
	return vL;
}

static int
linit(lua_State *L){
	struct font_manager *F = (struct font_manager*)lua_touserdata(L, lua_upvalueindex(1));
	const char* boot = luaL_checkstring(L, 1);
	font_manager_init(F, luavm_create(L, boot));
	lua_pushlightuserdata(L, F);
	return 1;
}

LUAMOD_API int
luaopen_font_init(lua_State *L) {
	luaL_checkversion(L);
	struct font_manager * F = (struct font_manager *)lua_newuserdatauv(L, sizeof(*F), 0);
	lua_pushcclosure(L, linit, 1);
	return 1;
}
