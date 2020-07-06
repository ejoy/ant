#define LUA_LIB

#include <lua.h>
#include <lauxlib.h>
#include <bgfx/c99/bgfx.h>

#include "bgfx_interface.h"
#include "luabgfx.h"
#include "font_manager.h"


/* _________________________________
  |(0,0) |                          |
  |      v (sprite_rect)            |
  |      |                          |
  |      | ____________  _____      |
  |<--u-->|         |  |   |        |
  |       |         y  | height     |
  |       |<-x->*  _|_ |   |        |
  |       |____________| __|__      |
  |                                 |
  |       |<--width--->|            |
  |                                 |
  |_________________________________|
*/

#define MAX_RECT 4096

#define FIXPOINT 8

#define TYPE_NULL 0
#define TYPE_SPRITE 1
#define TYPE_RECT 2
#define TYPE_TEXT 3
#define TYPE_COUNT 4

struct sprite_rect {
	int texid;
	uint16_t u;
	uint16_t v;
	uint16_t width;
	uint16_t height;
	int16_t x;
	int16_t y;
};

struct context {
	int type;
	int size;
	bgfx_transient_vertex_buffer_t tvb;
	bgfx_index_buffer_handle_t ib;
	bgfx_vertex_layout_t rect_layout;
	bgfx_vertex_layout_t text_layout;
	struct font_manager fm;
};

struct buffer_rect {
	int16_t p[2];
	uint8_t c[4];
};

struct buffer_text {
	int16_t p[2];
	int16_t u;
	int16_t v;
	uint8_t c[4];
};

static struct context *
new_context(lua_State *L) {
	struct context *c = (struct context *)lua_newuserdatauv(L, sizeof(struct context), 0);
	lua_setfield(L, LUA_REGISTRYINDEX, "BGFX_UI_CONTEXT");
	c->type = TYPE_NULL;
	c->size = 0;
	c->ib.idx = UINT16_MAX;	// invalid
	BGFX(vertex_layout_begin)(&c->rect_layout, BGFX_RENDERER_TYPE_NOOP);
	BGFX(vertex_layout_add)(&c->rect_layout, BGFX_ATTRIB_POSITION, 2, BGFX_ATTRIB_TYPE_INT16, true, false);
	BGFX(vertex_layout_add)(&c->rect_layout, BGFX_ATTRIB_COLOR0, 4, BGFX_ATTRIB_TYPE_UINT8, true, false);
	BGFX(vertex_layout_end)(&c->rect_layout);

	BGFX(vertex_layout_begin)(&c->text_layout, BGFX_RENDERER_TYPE_NOOP);
	BGFX(vertex_layout_add)(&c->text_layout, BGFX_ATTRIB_POSITION, 2, BGFX_ATTRIB_TYPE_INT16, true, false);
	BGFX(vertex_layout_add)(&c->text_layout, BGFX_ATTRIB_TEXCOORD0, 2, BGFX_ATTRIB_TYPE_INT16, true, false);
	BGFX(vertex_layout_add)(&c->text_layout, BGFX_ATTRIB_COLOR0, 4, BGFX_ATTRIB_TYPE_UINT8, true, false);
	BGFX(vertex_layout_end)(&c->text_layout);

	font_manager_init(&c->fm);

	return c;
}

static inline void
check_ib(struct context *c) {
	if (c->ib.idx == UINT16_MAX) {
		const bgfx_memory_t * mem = BGFX(alloc)(sizeof(uint16_t) * 6 * MAX_RECT);
		int i;
		for (i=0;i<MAX_RECT;i++) {
			uint16_t * index = ((uint16_t *)mem->data) + i*6;
			uint16_t idx_base = i*4;
			index[0] = idx_base+0;
			index[1] = idx_base+1;
			index[2] = idx_base+2;
			index[3] = idx_base+1;
			index[4] = idx_base+3;
			index[5] = idx_base+2;
		}
		c->ib = BGFX(create_index_buffer)(mem, BGFX_BUFFER_NONE);
	}
}

static void
push_typename(lua_State *L, int type) {
	static const char * name[] = {
		"NULL",
		"SPRITE",
		"RECT",
		"TEXT",
	};
	if (type < 0 || type >= TYPE_COUNT)
		luaL_error(L, "Invalid type %d", type);
	lua_pushstring(L, name[type]);
}

static int
push_typeargs(lua_State *L, int type) {
	switch(type) {
	case TYPE_RECT:
		return 1;
	case TYPE_TEXT:
		return 1;
	default:
		return luaL_error(L, "Invalid type %d", type);
	}
}

static int
check_submit(lua_State *L, struct context *c, int type, int size) {
	if (c->type != type || c->size + size > MAX_RECT) {
		int ret = 0;
		if (c->size > 0) {
			// submit
			BGFX(set_transient_vertex_buffer)(0, &c->tvb, 0, c->size * 4);
			check_ib(c);
			BGFX(set_index_buffer)(c->ib, 0, c->size * 6);
			BGFX(set_state)(BGFX_STATE_BLEND_NORMAL | BGFX_STATE_WRITE_RGB | BGFX_STATE_WRITE_A | BGFX_STATE_MSAA, 0);
			push_typename(L, c->type);
			ret = push_typeargs(L, c->type);
		}
		switch (type) {
		case TYPE_RECT:
			BGFX(alloc_transient_vertex_buffer)(&c->tvb, MAX_RECT, &c->rect_layout);
			break;
		case TYPE_TEXT:
			BGFX(alloc_transient_vertex_buffer)(&c->tvb, MAX_RECT, &c->text_layout);
			break;
		case TYPE_NULL:
			break;
		default:
			return luaL_error(L, "Invalid type %d", type);
		}
		c->size = 0;
		c->type = type;
		return ret;
	}
	return 0;
}

static inline struct buffer_rect *
get_buffer_rect(struct context *c) {
	return (struct buffer_rect *)(c->tvb.data + c->size * sizeof(struct buffer_rect) * 4);
}

static inline struct buffer_text *
get_buffer_text(struct context *c) {
	return (struct buffer_text *)(c->tvb.data + c->size * sizeof(struct buffer_text) * 4);
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

static inline void
fill_rect(struct buffer_rect * rect, int16_t x0, int16_t y0, int16_t x1, int16_t y1, uint32_t color) {
	rect[0].p[0] = x0;
	rect[0].p[1] = y0;
	rect[1].p[0] = x1;
	rect[1].p[1] = y0;
	rect[2].p[0] = x0;
	rect[2].p[1] = y1;
	rect[3].p[0] = x1;
	rect[3].p[1] = y1;

	int i;
	uint8_t c[4] = {
		(color >> 16) & 0xff,
		(color >> 8) & 0xff,
		color & 0xff,
		(color >> 24) & 0xff,
	};

	for (i=0;i<4;i++) {
		rect[i].c[0] = c[0];
		rect[i].c[1] = c[1];
		rect[i].c[2] = c[2];
		rect[i].c[3] = c[3]; 
	}
}

/*
	number x
	number y
	number width
	number height
	integer color
	number alpha (default = 1.0)
 */
static int
lsubmit_rect(lua_State *L) {
	struct context *c = (struct context *)lua_touserdata(L, lua_upvalueindex(1));
	int ret = check_submit(L, c, TYPE_RECT, 1);
	struct buffer_rect *rect = get_buffer_rect(c);
	int16_t x0 = read_fixpoint(L, 1);
	int16_t y0 = read_fixpoint(L, 2);
	int16_t width = read_fixpoint(L, 3);
	int16_t height = read_fixpoint(L, 4);

	uint32_t color = luaL_checkinteger(L, 5);
	if (lua_isnoneornil(L, 6)) {
		color |= 0xff000000;
	} else {
		float a = luaL_checknumber(L, 6);
		uint8_t inta = (uint8_t)a * 255;
		uint32_t green = color & 0xff00;
		color &= 0xff00ff;
		color *= inta;
		green *= inta;
		color = ((color | green) >> 8) | (inta << 24);
	}
	fill_rect(rect, x0, y0, x0 + width, y0 + height, color);
	++c->size;

	return ret;
}

/*
	number x
	number y
	number width
	number height
	integer color
	number line_width (default = 1.0)
 */

static int
lsubmit_frame(lua_State *L) {
	struct context *c = (struct context *)lua_touserdata(L, lua_upvalueindex(1));
	int ret = check_submit(L, c, TYPE_RECT, 4);
	struct buffer_rect *rect = get_buffer_rect(c);
	int16_t x = read_fixpoint(L, 1);
	int16_t y = read_fixpoint(L, 2);
	int16_t width = read_fixpoint(L, 3);
	int16_t height = read_fixpoint(L, 4);
	int16_t line_width = FIXPOINT;
	if (!lua_isnoneornil(L, 6)) {
		line_width = read_fixpoint(L, 6);
	}
	uint32_t color = luaL_checkinteger(L, 5) | 0xff000000;
	fill_rect(rect+0, x, y, x + width, y + line_width, color);
	fill_rect(rect+4, x, y+height-line_width, x + width, y + height, color);
	fill_rect(rect+8, x, y+line_width, x + line_width, y + height - line_width, color);
	fill_rect(rect+12, x+width-line_width, y+line_width, x+width, y + height - line_width, color);
	c->size += 4;
	return ret;
}

static int
lsubmit_null(lua_State *L) {
	struct context *c = (struct context *)lua_touserdata(L, lua_upvalueindex(1));
	font_manager_flush(&c->fm);
	return check_submit(L, c, TYPE_NULL, 0);
}

static const void *
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

static struct font_manager *
getF(lua_State *L) {
	struct context *c = (struct context *)lua_touserdata(L, lua_upvalueindex(1));
	return &c->fm;
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

struct prepare {
	struct font_manager *F;
	bgfx_texture_handle_t texid;
	short fontid;
	int codepoint;
};

static inline void
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

static const char *utf8_decode (const char *s, utfint *val, int strict) {
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


/*
	handle texture
	string text
	integer fontid (default = 0)

	return advance_x, advance_y
 */
static int
lprepare_text(lua_State *L) {
	uint16_t texture_id = BGFX_LUAHANDLE_ID(TEXTURE, luaL_checkinteger(L, 1));
	bgfx_texture_handle_t th = {texture_id};
	size_t sz;
	const char * str = luaL_checklstring(L, 2, &sz);
	const char * end_ptr = str + sz;
	struct context *c = (struct context *)lua_touserdata(L, lua_upvalueindex(1));
	struct font_manager *F = &c->fm;
	int fontid = luaL_optinteger(L, 3, 0);

	int advance_x=0, advance_y=0;
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
		} else {
			return luaL_error(L, "Invalid utf8 text");
		}
	}

	lua_pushinteger(L, advance_x);
	lua_pushinteger(L, advance_y);
	return 2;
}

static inline void
fill_text(struct font_manager *F, struct buffer_text * rect, int16_t x0, int16_t y0, uint32_t color, int size, struct font_glyph *g) {
	unsigned short w = g->w;
	unsigned short h = g->h;
	font_manager_scale(F, g, size);

	x0 += g->offset_x * FIXPOINT;
	y0 += g->offset_y * FIXPOINT;

	int16_t x1 = x0 + g->w * FIXPOINT;
	int16_t y1 = y0 + g->h * FIXPOINT;

	int16_t u0 = g->u * (0x8000 / FONT_MANAGER_TEXSIZE);
	int16_t v0 = g->v * (0x8000 / FONT_MANAGER_TEXSIZE);

	int16_t u1 = (g->u + w) * (0x8000 / FONT_MANAGER_TEXSIZE);
	int16_t v1 = (g->v + h) * (0x8000 / FONT_MANAGER_TEXSIZE);

	rect[0].p[0] = x0;
	rect[0].p[1] = y0;
	rect[1].p[0] = x1;
	rect[1].p[1] = y0;
	rect[2].p[0] = x0;
	rect[2].p[1] = y1;
	rect[3].p[0] = x1;
	rect[3].p[1] = y1;
	
	rect[0].u = u0;
	rect[0].v = v0;
	rect[1].u = u1;
	rect[1].v = v0;
	rect[2].u = u0;
	rect[2].v = v1;
	rect[3].u = u1;
	rect[3].v = v1;

	int i;
	uint8_t c[4] = {
		(color >> 16) & 0xff,
		(color >> 8) & 0xff,
		color & 0xff,
		(color >> 24) & 0xff,
	};

	for (i=0;i<4;i++) {
		rect[i].c[0] = c[0];
		rect[i].c[1] = c[1];
		rect[i].c[2] = c[2];
		rect[i].c[3] = c[3]; 
	}
}

/*
	number x
	number y
	integer size
	integer color
	integer codepoint
	integer fontid (default = 0)
 */
static int
lsubmit_char(lua_State *L) {
	int16_t x = read_fixpoint(L, 1);
	int16_t y = read_fixpoint(L, 2);
	int size = luaL_checkinteger(L, 3);
	uint32_t color = luaL_checkinteger(L, 4) | 0xff000000;	// todo : alpha text
	int codepoint = luaL_checkinteger(L, 5);
	int fontid = luaL_optinteger(L, 6, 0);

	struct context *c = (struct context *)lua_touserdata(L, lua_upvalueindex(1));
	struct font_manager *F = &c->fm;
	
	struct font_glyph g;
	if (font_manager_touch(F, fontid, codepoint, &g) <= 0)	// not in cache
		return 0;
	
	int ret = check_submit(L, c, TYPE_TEXT, 1);
	struct buffer_text *bt = get_buffer_text(c);
	fill_text(F, bt, x, y, color, size, &g);
	++c->size;
	return ret;
}

LUAMOD_API int
luaopen_bgfx_ui(lua_State *L) {
	luaL_checkversion(L);
	init_interface(L);

	luaL_Reg l[] = {
		{ "fonttexture_size", NULL },
		{ "addfont", laddfont },
		{ "rebind", lrebindfont },
		{ "prepare_text", lprepare_text },
		{ "submit_char", lsubmit_char },
//		{ "new_sprite", lnew_sprite },
//		{ "submit_sprite", lsubmit_sprite },
		{ "submit_rect", lsubmit_rect },
		{ "submit_frame", lsubmit_frame },
		{ "submit", lsubmit_null },
		{ NULL, NULL },
	};
	struct context * c = new_context(L);
	luaL_newlibtable(L, l);
	lua_pushlightuserdata(L, (void *)c);
	luaL_setfuncs(L, l, 1);
	lua_pushinteger(L, FONT_MANAGER_TEXSIZE);
	lua_setfield(L, -2, "fonttexture_size");
	return 1;
}
