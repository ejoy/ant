#define LUA_LIB

#include <lua.h>
#include <lauxlib.h>
#include <string.h>

#include "font_define.h"
#include "truetype.h"

static const unsigned char *
get_ttfbuffer(lua_State *L, int index) {
	int t = lua_type(L, index);
	if (t == LUA_TSTRING) {
		return (const unsigned char *)lua_tostring(L, index);
	} else if (t == LUA_TUSERDATA || t == LUA_TLIGHTUSERDATA) {
		return (const unsigned char *)lua_touserdata(L, index);
	}
	luaL_error(L, "Invalid ttfbuffer type = %s", lua_typename(L, t));
	return NULL;
}

// integer fontid (base 1)
// string/userdata fontdata
// integer index / string name
static int
lupdate_cstruct(lua_State *L) {
	struct truetype_font * f = truetype_cstruct(L);
	int fontid = luaL_checkinteger(L, 1);
	if (fontid < 1 || fontid > MAX_FONT_NUM)
		return luaL_error(L, "The font id %d is out of %d", fontid, MAX_FONT_NUM);
	const unsigned char * data = get_ttfbuffer(L, 2);
	if (data == NULL)
		return luaL_error(L, "Invalid font data for %d", fontid);
	int type = lua_type(L, 3);
	int offset = 0;
	if (type == LUA_TSTRING) {
		offset = stbtt_FindMatchingFont(data, lua_tostring(L, 3), STBTT_MACSTYLE_DONTCARE);
		if (offset < 0)
			return luaL_error(L, "Can't find %s in font %d",  lua_tostring(L, 3), fontid);
	} else {
		int index = luaL_optinteger(L, 3, 0);
		offset = stbtt_GetFontOffsetForIndex(data, index);
		if (offset < 0)
			return luaL_error(L, "Invalid offset for font %d index %d", fontid, index);
	}

	--fontid;
	if (stbtt_InitFont(&f->fontinfo[fontid], data, offset) == 0)
		return luaL_error(L, "InitFont %d with failed", fontid+1);
	f->enable |= (uint64_t)(1 << fontid);

	lua_pushlightuserdata(L, &f->fontinfo[fontid]);
	return 1;
}

// integer fontid (base 1)
static int
lunload_cstruct(lua_State *L) {
	struct truetype_font * f = truetype_cstruct(L);
	int fontid = luaL_checkinteger(L, 1);
	if (fontid < 1 || fontid > MAX_FONT_NUM)
		return luaL_error(L, "The font id %d is out of %d", fontid, MAX_FONT_NUM);
	--fontid;
	f->enable &= ~(1 << fontid);
	return 0;
}

// string/userdata data
// integer index
// integer platid
// integer encodeid
// integer langid
// return string utf-16 family, sub-family
static int
lnamestring(lua_State *L) {
	const unsigned char * data = get_ttfbuffer(L, 1);
	int index = luaL_checkinteger(L, 2);
	stbtt_fontinfo font;
	int offset = stbtt_GetFontOffsetForIndex(data, index);
	if (offset < 0) {
		return 0;
	}
	if (stbtt_InitFont(&font, data, offset) == 0)
		return luaL_error(L, "InitFont with index %d failed", index);
	int platid = luaL_checkinteger(L, 3);
	int encodeid = luaL_checkinteger(L, 4);
	int langid = luaL_checkinteger(L, 5);
	int len = 0;
	const char * family = stbtt_GetFontNameString(&font, &len, platid, encodeid, langid, 1);
	if (family) {
		lua_pushlstring(L, family, len);
	} else {
		lua_pushboolean(L, 0);
		return 1;
	}
	const char * subfam = stbtt_GetFontNameString(&font, &len, platid, encodeid, langid, 2);
	if (subfam) {
		lua_pushlstring(L, subfam, len);
	} else {
		return 1;
	}
	return 2;
}

static void
init_cstruct(lua_State *L) {
	struct truetype_font *f = (struct truetype_font *)lua_newuserdatauv(L, sizeof(*f), 0);
	f->enable = 0;
	lua_setfield(L, LUA_REGISTRYINDEX, TRUETYPE_CSTRUCT);
}

static int
ltestname(lua_State *L) {
	const char * name = luaL_checkstring(L, 1);
	int id = truetype_name(L, name);
	lua_pushinteger(L, id);
	return 1;
}

static int
ltestinfo(lua_State *L) {
	int id = luaL_checkinteger(L, 1);
	struct truetype_font * f = truetype_cstruct(L);
	const stbtt_fontinfo *info = truetype_font(f, id, L);
	lua_pushlightuserdata(L, (void *)info);
	return 1;
}

LUAMOD_API int
luaopen_font_truetype(lua_State *L) {
	luaL_checkversion(L);
	init_cstruct(L);
	luaL_Reg l[] = {
		{ "update", lupdate_cstruct },
		{ "unload", lunload_cstruct },
		{ "namestring", lnamestring },
		{ "testname", ltestname },	// test C api : truetype_name
		{ "testinfo", ltestinfo },	// test C api : truetype_font
		{ "nametable", NULL },
		{ "idtable", NULL },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);

	lua_newtable(L);
	lua_pushvalue(L, -1);
	lua_setfield(L, LUA_REGISTRYINDEX, TRUETYPE_NAME);
	lua_setfield(L, -2, "nametable");

	lua_newtable(L);
	lua_pushvalue(L, -1);
	lua_setfield(L, LUA_REGISTRYINDEX, TRUETYPE_ID);
	lua_setfield(L, -2, "idtable");

	return 1;
}
