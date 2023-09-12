#define LUA_LIB

#include <lua.h>
#include <lauxlib.h>
#include <stdint.h>
#include "luabgfx.h"
#include "textureman.h"

#define TEXTURE_MAX_ID 0x7fff

static uint16_t g_texture[TEXTURE_MAX_ID];
static uint16_t g_texture_id = 0;
static uint32_t g_frame = 0;
static uint32_t g_texture_timestamp[TEXTURE_MAX_ID];

static int
ltexture_create(lua_State *L) {
	uint16_t handle = BGFX_LUAHANDLE_ID(TEXTURE, (int)luaL_checkinteger(L, 1));
	if (g_texture_id >= TEXTURE_MAX_ID) {
		return luaL_error(L, "Too many textures");
	}
	int id = g_texture_id++;
	g_texture[id] = handle;
	g_texture_timestamp[id] = g_frame;
	lua_pushinteger(L, id+1);
	return 1;
}

static inline int
checktextureid(lua_State *L, int index) {
	int id = (int)luaL_checkinteger(L, index);
	if (id <= 0 || id > g_texture_id)
		return luaL_error(L, "Invalid texture handle %d", id);
	return id;
}

static int
ltexture_get(lua_State *L) {
	int id = checktextureid(L, 1);
	uint16_t h = g_texture[id - 1];
	g_texture_timestamp[id - 1] = g_frame;
	int luahandle = (BGFX_HANDLE_TEXTURE << 16) | h;
	lua_pushinteger(L, luahandle);
	return 1;
}

static int
texture_transform(int id) {
	bgfx_texture_handle_t handle = BGFX_INVALID_HANDLE;
	if (id <= 0 || id > g_texture_id)
		return handle.idx;
	uint16_t h = g_texture[id - 1];
	g_texture_timestamp[id - 1] = g_frame;
	return h;
}

bgfx_texture_handle_t
texture_get(int id) {
	bgfx_texture_handle_t handle = { texture_transform(id) };
	return handle;
}

static int
ltexture_set(lua_State *L) {
	int id = checktextureid(L, 1);
	uint16_t handle = BGFX_LUAHANDLE_ID(TEXTURE, (int)luaL_checkinteger(L, 2));
	g_texture[id - 1] = handle;
	return 0;
}

static int
lframe_tick(lua_State *L) {
	int f = g_frame++;
	lua_pushinteger(L, f);
	return 1;
}

static inline uint32_t
read_timestamp(int index) {
	uint32_t t = g_texture_timestamp[index];
	return (uint32_t)(g_frame - t);
}

static int
ltexture_timestamp(lua_State *L) {
	if (lua_istable(L, 1)) {
		lua_settop(L, 1);
		int n = (int)lua_rawlen(L, 1);
		int i;
		for (i=1;i<=n;i++) {
			lua_geti(L, 1, i);
			int id = checktextureid(L, -1);
			lua_pop(L, 1);
			int t = read_timestamp(id - 1);
			lua_pushinteger(L, t);
			lua_seti(L, 1, i);
		}
	} else {
		int id = checktextureid(L, 1);
		int t = read_timestamp(id - 1);
		lua_pushinteger(L, t);
	}
	return 1;
}

static inline int
is_invalid(int id, uint16_t* filter, size_t filter_n) {
	for (size_t i = 0; i < filter_n; ++i) {
		if (g_texture[id] == filter[i]) {
			return 1;
		}
	}
	return 0;
}

static void
frame_get(lua_State *L,int index, int range, uint16_t* filter, size_t filter_n) {
	int i;
	int n = 0;
	if (range >= 0) {
		// filter new
		for (i=0;i<g_texture_id;i++) {
			if (is_invalid(i, filter, filter_n) && (int)read_timestamp(i) <= range) {
				lua_pushinteger(L, i+1);
				lua_rawseti(L, index, ++n);
			}
		}
	} else {
		// filter old
		int old = - range;
		for (i=0;i<g_texture_id;i++) {
			if (!is_invalid(i, filter, filter_n) && (int)read_timestamp(i) >= old) {
				lua_pushinteger(L, i+1);
				lua_rawseti(L, index, ++n);
			}
		}
	}
	int on = (int)lua_rawlen(L, index);
	for (i=n+1;i<=on;i++) {
		lua_pushnil(L);
		lua_rawseti(L, index, i);
	}
}

static void
check_result(lua_State *L, int index) {
	if (lua_isnoneornil(L, index)) {
		lua_settop(L, index-1);
		lua_newtable(L);
	} else {
		luaL_checktype(L, index, LUA_TTABLE);
		lua_settop(L, index);
	}
}

static int
lframe_new(lua_State *L) {
	int range = (int)luaL_optinteger(L, 1, 0);
	if (range < 0)
		return luaL_error(L, "Invalid range %d", range);
	size_t sz = 0;
	const char* filter = luaL_checklstring(L, 2, &sz);
	check_result(L, 3);
	frame_get(L, 3, range, (uint16_t*)filter, sz / sizeof(uint16_t));
	return 1;
}

static int
lframe_old(lua_State *L) {
	int range = (int)luaL_checkinteger(L, 1);
	if (range <= 0)
		return luaL_error(L, "Invalid range %d", range);
	size_t sz = 0;
	const char* filter = luaL_checklstring(L, 2, &sz);
	check_result(L, 3);
	frame_get(L, 3, -range, (uint16_t*)filter, sz / sizeof(uint16_t));
	return 1;
}

LUAMOD_API int
luaopen_textureman_client(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "texture_get", ltexture_get },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	lua_pushlightuserdata(L, texture_transform);
	lua_setfield(L, -2, "texture_get_cfunc");
	return 1;
}

LUAMOD_API int
luaopen_textureman_server(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "texture_create", ltexture_create },
		{ "texture_set", ltexture_set },
		{ "texture_timestamp", ltexture_timestamp },
		{ "frame_tick", lframe_tick },
		{ "frame_new", lframe_new },
		{ "frame_old", lframe_old },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);	

	return 1;
}
