#ifndef ant_truetype_h
#define ant_truetype_h

#include <lua.h>
#include <lauxlib.h>
#include <stdint.h>

#include <stb/stb_truetype.h>

#define TRUETYPE_ID "TRUETYPE_ID"
#define TRUETYPE_NAME "TRUETYPE_NAME"
#define TRUETYPE_CSTRUCT "TRUETYPE_CSTRUCT"
#define TRUETYPE_IMPORT "TRUETYPE_IMPORT"

struct truetype_font {
	uint64_t enable;
	stbtt_fontinfo fontinfo[MAX_FONT_NUM];
};

// get global struct truetype_font
static inline struct truetype_font *
truetype_cstruct(lua_State *L) {
	if (lua_getfield(L, LUA_REGISTRYINDEX, TRUETYPE_CSTRUCT) != LUA_TUSERDATA) {
		lua_pop(L, 1);
		return NULL;
	}
	struct truetype_font *ret = (struct truetype_font *)lua_touserdata(L, -1);
	lua_pop(L, 1);
	return ret;
}

static inline int
lget_fontdata(lua_State *L) {
	int fontid = (int)lua_tointeger(L, 1);
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
	if (fontid < 1 || fontid > MAX_FONT_NUM) {
		fontid = 0;
	} else {
		--fontid;
	}

	if (ttf->enable & (uint64_t)1 << fontid) {
		return &ttf->fontinfo[fontid];
	}
	if (L == NULL) {
		return default_info(ttf);
	}

	lua_pushcfunction(L, lget_fontdata);
	lua_pushinteger(L, fontid+1);
	if (lua_pcall(L, 1, 1, 0) != LUA_OK) {
		printf("TRUETYPE_ID err: %s\n", lua_tostring(L, -1));
		lua_pop(L, 1);
		return default_info(ttf);
	}

	const stbtt_fontinfo * info = (const stbtt_fontinfo*)lua_touserdata(L, -1);
	lua_pop(L, 1);
	if (info == NULL) {
		return default_info(ttf);
	}
	return info;
}

static inline int
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
	if (lua_pcall(L, 1, 1, 0) != LUA_OK) {
		printf("TRUETYPE_NAME err: %s\n", lua_tostring(L, -1));
		lua_pop(L, 1);
		return 0;
	}
	int fontid = 0;
	if (lua_type(L, -1) == LUA_TNUMBER) {
		fontid = (int)lua_tointeger(L, -1);
	}
	lua_pop(L, 1);
	return fontid;
}

static inline int
import_font(lua_State *L) {
	if (lua_getfield(L, LUA_REGISTRYINDEX, TRUETYPE_IMPORT) != LUA_TFUNCTION) {
		return 0;
	}
	lua_pushvalue(L, 1);
	lua_call(L, 1, 0);
	return 0;
}

static inline void
truetype_import(lua_State *L, void* fontdata) {
	lua_pushcfunction(L, import_font);
	lua_pushlightuserdata(L, fontdata);
	if (lua_pcall(L, 1, 0, 0) != LUA_OK) {
		printf("TRUETYPE_IMPORT err: %s\n", lua_tostring(L, -1));
		lua_pop(L, 1);
	}
}

#endif
