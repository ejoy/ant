
#include <lua.hpp>
#include <cassert>
#include <cstring>
#include <bgfx/c99/bgfx.h>
#include <iostream>
#include<vector>
#include<string>
#include<unordered_map>
#include<assert.h>
#include <font_manager.h>
#include <string.h>
#include <stdint.h>
#include <stdlib.h>
#include <ctype.h>
#include<memory>
#include<bgfx_interface.h>
#include "luabgfx.h"
#include "truetype.h"

static struct font_manager* fm=new font_manager();

typedef unsigned int utfint;
#define MAXUNICODE	0x10FFFFu
#define MAXUTF		0x7FFFFFFFu
#define FIXPOINT FONT_POSTION_FIX_POINT

std::unordered_map<uint8_t, uint8_t> ctod{
    {'0',0x00},
    {'1',0x01},
    {'2',0x02},
    {'3',0x03},
    {'4',0x04},
    {'5',0x05},
    {'6',0x06},
    {'7',0x07},
    {'8',0x08},
    {'9',0x09},
    {'a',0x0a},
    {'b',0x0b},
    {'c',0x0c},
    {'d',0x0d},
    {'e',0x0e},
    {'f',0x0f},
};

struct quad_text{
    int16_t p[2];
    int16_t u, v;
    uint32_t color;
};

static struct font_manager* 
getF(lua_State *L){
    return (struct font_manager*)lua_touserdata(L, lua_upvalueindex(1));
}

const char* utf8_decode(const char* s, utfint* val, int strict,int& cnt) {
    static const utfint limits[] =
    { ~(utfint)0, 0x80, 0x800, 0x10000u, 0x200000u, 0x4000000u };
    unsigned int c = (unsigned char)s[0];
    utfint res = 0;  /* final result */
    if (c < 0x80)  /* ascii? */
        res = c,cnt=0;
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
        cnt=count;
    }
    if (strict) {
        /* check for invalid code points; too large or surrogates */
        if (res > MAXUNICODE || (0xD800u <= res && res <= 0xDFFFu))
            return NULL;
    }
    if (val) *val = res;
    cnt+=1;
    return s + 1;  /* +1 to include first byte */
}

struct layout {
    uint32_t color;
    uint32_t fontid;
    uint16_t num;
    uint16_t start;
};

static std::vector<uint32_t> cps;
//uint8_t default_fontid = 1;
//uint32_t default_color = 0x00000000;

static void
release_char_memory(void *d, void *u){
	free(d);
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

static void
prepare_char(struct font_manager* F, uint16_t texid, int fontid, int codepoint, int *advance_x, int *advance_y) {
	struct font_glyph g;
	int ret = F->font_manager_touch(F, fontid, codepoint, &g);
	*advance_x = g.advance_x;
	*advance_y = g.advance_y;

	if (ret < 0) {	// failed
		// todo: report overflow
		return;
	}

	if (ret == 0 && is_truetypefont(fontid)) {
		uint8_t *mem = (uint8_t *)malloc(g.w * g.h);
		const char * err = F->font_manager_update(F, fontid, codepoint, &g, mem);
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
    struct font_manager *F = getF(L);
	uint16_t texid = luaL_checkinteger(L, 1);
	size_t sz;
	const char * text = luaL_checklstring(L, 2, &sz);
	const char * end_ptr = text + sz;
    const int size = luaL_checkinteger(L, 3);
	int default_fontid = luaL_optinteger(L, 4, 0);
    int default_color=luaL_optinteger(L,5,0);
    int bit_color=0x000000;

    int i = 0;
    int n = sz;
    std::vector<layout> layoutlist;
    std::vector<uint32_t> codepoints;
    int advance_x=0, advance_y=0;
    uint16_t start = 0;
    while (text[i]) {

        layout l;
        uint32_t color = default_color;
        uint16_t num = 0;
        uint8_t fontid = default_fontid;
        l.start = start;
        
        assert(i < n && text[i] != ']');

        if (text[i] == '[') {
            assert((i + 1) < n && text[i + 1] == '#');
            i++; 
            uint8_t cb=0;
            color=bit_color;
            while ((i + 1) < n && text[i + 1] != ']') {
                assert(ctod.find(text[i + 1]) != ctod.end());
                color = color | (ctod[text[i + 1]] << ((7 - cb) * 4));
                cb++;
                i++;
            }

            assert((i + 1) < n && text[i + 1] == ']');

            i++;
            l.color = color;
            
            while (i + 1 < n && text[i + 1] != '[') {
                uint32_t codepoint = 0;
                const char* str = (const char*)&text[i+1];
                int cnt=0;
                str=utf8_decode(str, &codepoint, 1,cnt);
                codepoints.emplace_back(codepoint);
                if (str) {
                    int x,y;
                    prepare_char(F, texid, fontid, codepoint, &x, &y);
                    advance_x += x;
                    if (y > advance_y) {
                        advance_y = y;
                    }
                    start++;
                    num++;
                    i+=cnt;//汉字+=3 英文字符+=1
                } 
                else {
                    return luaL_error(L, "Invalid utf8 text");
                }                            
            }
            assert(i + 3 < n && text[i + 1] == '[' && text[i + 2] == '#' && text[i + 3] == ']');
            l.num = num;
            l.fontid = fontid;
            i += 3;
            ++i;
        }
        else {
            uint32_t codepoint = 0;
            const char* str = (const char*)&text[i];
            int cnt=0;
            str=utf8_decode(str, &codepoint, 1,cnt);
            codepoints.emplace_back(codepoint);

            if (str) {
                int x,y;
                prepare_char(F, texid, fontid, codepoint, &x, &y);
                advance_x += x;
                if (y > advance_y) {
                    advance_y = y;
                }
                l.num = 1;
                l.fontid = fontid;
                l.color = color;
                start++;
                i+=cnt;//汉字+=3 英文字符+=1
            } 
            else {
                return luaL_error(L, "Invalid utf8 text");
            }
        }
        layoutlist.emplace_back(l);
    }

    struct font_glyph t_g = {0};
    t_g.advance_x = advance_x;
    t_g.advance_y = advance_y;

    F->font_manager_scale(F, &t_g, size);
    lua_createtable(L,layoutlist.size(),0);
    for(int ii=0;ii<layoutlist.size();++ii){
        auto& l=layoutlist[ii];
        lua_createtable(L,0,4);
        lua_pushinteger(L,l.color);
        lua_setfield(L,-2,"color");
        lua_pushinteger(L,l.fontid);
        lua_setfield(L,-2,"fontid");
        lua_pushinteger(L,l.num);
        lua_setfield(L,-2,"num");
        lua_pushinteger(L,l.start);
        lua_setfield(L,-2,"start");
        lua_rawseti(L,-2,ii+1);
    }
    lua_createtable(L,codepoints.size(),0);
    for(int ii=0;ii<codepoints.size();++ii){
        auto& cp=codepoints[ii];
        lua_pushinteger(L,cp);
        lua_rawseti(L,-2,ii+1);
    }
    lua_pushinteger(L, t_g.advance_x);
    lua_pushinteger(L, t_g.advance_y);

    cps.resize(codepoints.size());
    cps=codepoints;
    return 4;
}

static void
fill_text_quad(struct font_manager *F, struct quad_text * qt,
	int16_t x0, int16_t y0, uint16_t texw, uint16_t texh,
	uint32_t color, int size, struct font_glyph *g) {
	unsigned short w = g->w;
	unsigned short h = g->h;
//	printf("fill %d %d %d %d %d\n", x0, g->u, g->v, w, h);
	F->font_manager_scale(F, g, size);

	x0 += g->offset_x * FIXPOINT;
	y0 += g->offset_y * FIXPOINT;

	int16_t x1 = x0 + g->w * FIXPOINT;
	int16_t y1 = y0 + g->h * FIXPOINT;

	int16_t u0 = g->u * (0x8000 / texw);
	int16_t v0 = g->v * (0x8000 / texh);

	int16_t u1 = (g->u + w) * (0x8000 / texw);
	int16_t v1 = (g->v + h) * (0x8000 / texh);

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

static int
lload_text_quad(lua_State *L){
    struct font_manager *fm = getF(L);

	struct memory* m = (struct memory*)lua_touserdata(L, 1);

	const int fontid = (int)luaL_checkinteger(L, 2);

    const uint32_t offset=(uint32_t)luaL_checkinteger(L,3);

    //int16_t x = read_fixpoint(L, 4);
    //int16_t y = read_fixpoint(L, 5);

    int16_t x=(int16_t)luaL_checknumber(L, 4);
    int16_t y=(int16_t)luaL_checknumber(L, 5);

	const uint16_t texw = (uint16_t)luaL_checkinteger(L, 6);
	const uint16_t texh = (uint16_t)luaL_checkinteger(L, 7);

    const int fontsize = (int)luaL_checkinteger(L, 8);

    const uint32_t color = (uint32_t)luaL_checkinteger(L, 9);
    const uint16_t num=(uint16_t)luaL_checkinteger(L,10);
    const uint16_t start=(uint16_t)luaL_checkinteger(L,11);

	struct quad_text *qt = (struct quad_text *)m->data;;
    qt+=offset;
    struct font_glyph g = {0};
    for(int ii=0;ii<num;++ii){
        int i=start+ii;
        utfint codepoint=cps[i];
        if (codepoint){
            if (fm->font_manager_touch(fm, fontid, codepoint, &g )< 0){
                luaL_error(L, "codepoint:%d, is not cache, need call 'prepare_text' first", codepoint);
            }
            fill_text_quad(fm, qt, x, y, texw, texh, color, fontsize, &g);
            x += g.advance_x * FIXPOINT;
            qt += 4;
        }        
    }
    lua_pushinteger(L,x);
    lua_pushinteger(L,y);

    return 2;
}

static int 
initfont(lua_State *L){
    luaL_checktype(L, 2, LUA_TLIGHTUSERDATA);
    luaL_Reg lib[] = {
        { "prepare_text", lprepare_text},
        { "load_text_quad",lload_text_quad},
        { nullptr, nullptr },
    };

    luaL_setfuncs(L, lib, 1);
    return 1;
}

extern "C" int
luaopen_layout(lua_State* L) {
    // luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
    // luaL_Reg lib[] = {
    //     { "prepare_text", lprepare_text},
    //     { "load_text_quad",lload_text_quad},
    //     { nullptr, nullptr },
    // };

    // luaL_newlibtable(L, lib);
    // lua_pushvalue(L, 1);
    // luaL_setfuncs(L, lib, 1);
    luaL_checkversion(L);
	lua_newtable(L);
	lua_newtable(L);
	lua_pushcfunction(L, initfont);
	lua_setfield(L, -2, "__call");
	lua_setmetatable(L, -2);
    return 1;
}

/*  static int
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
luaopen_layout_init(lua_State *L) {
	luaL_checkversion(L);
	struct font_manager * F = (struct font_manager *)lua_newuserdatauv(L, sizeof(*F), 0);
	lua_pushcclosure(L, linit, 1);
	return 1;
} */
 
