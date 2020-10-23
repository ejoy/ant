#ifndef ant_truetype_h
#define ant_truetype_h

#include <lua.h>
#include <lauxlib.h>
#include <stdint.h>

#include <stb/stb_truetype.h>

#define TRUETYPE_ID "TRUETYPE_ID"
#define TRUETYPE_NAME "TRUETYPE_NAME"
#define TRUETYPE_CSTRUCT "TRUETYPE_CSTRUCT"
#define TRUETYPE_CAP 64

struct truetype_font {
	uint64_t enable;
	stbtt_fontinfo fontinfo[TRUETYPE_CAP];
};

// get global struct truetype_font
struct truetype_font *
truetype_cstruct(lua_State *L) {
	if (lua_getfield(L, LUA_REGISTRYINDEX, TRUETYPE_CSTRUCT) != LUA_TUSERDATA) {
		lua_pop(L, 1);
		return NULL;
	}
	struct truetype_font *ret = (struct truetype_font *)lua_touserdata(L, -1);
	lua_pop(L, 1);
	return ret;
}

static int
lget_fontdata(lua_State *L) {
	int fontid = lua_tointeger(L, 1);
	if (lua_getfield(L, LUA_REGISTRYINDEX, TRUETYPE_ID) != LUA_TTABLE) {
		return 0;
	}
	lua_geti(L, -1, fontid);
	return 1;
}

static inline const stbtt_fontinfo *
default_info(struct truetype_font *ttf) {
	if (ttf->enable & 1)
		return &ttf->fontinfo[0];
	return NULL;
}

// font id -> font info
static inline const stbtt_fontinfo *
truetype_font(struct truetype_font *ttf, int fontid, lua_State *L) {
	if (fontid < 1 || fontid > TRUETYPE_CAP) {
		fontid = 0;
	} else {
		--fontid;
	}

	if (ttf->enable & (1 << fontid)) {
		return &ttf->fontinfo[fontid];
	}
	if (L == NULL) {
		return default_info(ttf);
	}

	lua_pushcfunction(L, lget_fontdata);
	lua_pushinteger(L, fontid);
	if (lua_pcall(L, 1, 1, 0) != LUA_OK) {
		lua_pop(L, 1);
		return default_info(ttf);
	}

	const stbtt_fontinfo * info = lua_touserdata(L, -1);
	lua_pop(L, 1);
	if (info == NULL) {
		return default_info(ttf);
	}
	return info;
}

static int
lget_fontid(lua_State *L) {
	const char *name = (const char *)lua_touserdata(L, 1);
	if (lua_getfield(L, LUA_REGISTRYINDEX, TRUETYPE_NAME) != LUA_TTABLE) {
		return 0;
	}
	lua_getfield(L, -1, name);
	return 1;
}

// font name -> font id
static inline int
truetype_name(lua_State *L, const char *name) {
	lua_pushcfunction(L, lget_fontid);
	lua_pushlightuserdata(L, (void *)name);
	if (lua_pcall(L, 1, 1, 0) != LUA_OK ) {
		lua_pop(L, 1);
		return -1;
	}
	int fontid = lua_tointeger(L, -1);
	lua_pop(L, 1);
	return fontid;
}

#endif
