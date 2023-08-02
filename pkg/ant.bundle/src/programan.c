#define LUA_LIB

#include <lua.h>
#include <lauxlib.h>
#include <stdint.h>
#include <stdlib.h>
#include "luabgfx.h"
#include "programan.h"

#define PROGRAM_MAX 0x8000
#define REMOVE_MAX 1024
#define INVALID_HANDLE 0xffff

struct program_manager {
	int max;
	int n;
	int threshold_removed;
	int threshold_reserved;
	int id;
	int removed_n;
	int request;
	uint32_t frame;
	uint16_t map[PROGRAM_MAX];
	uint16_t removed[REMOVE_MAX];
	uint32_t timestamp[PROGRAM_MAX];
};

static struct program_manager g_man;

static inline int
checkid(lua_State *L, int index) {
	int id = (int)luaL_checkinteger(L, index);
	if (id <= 0 || id > g_man.id)
		return luaL_error(L, "Invalid program id %d", id);
	return id;
}

/*
	{
		max = bgfx.get_caps().limits.maxPrograms - bgfx.get_stats("n").numPrograms,
		threshold = nil, -- default is max * 2 / 3,
		reserved = nil, -- default is max / 2,
	}
*/
static int
lprogram_init(lua_State *L) {
	luaL_checktype(L, 1, LUA_TTABLE);
	int threshold_removed = 0;
	int threshold_reserved = 0;
	if (lua_getfield(L, 1, "max") != LUA_TNUMBER) {
		return luaL_error(L, "Need program .max");
	}
	int pmax = (int)lua_tointeger(L, -1);
	if (pmax < 1)
		return luaL_error(L, ".max %d is too small", pmax);
	lua_pop(L, 1);
	if (lua_getfield(L, 1, "threshold") != LUA_TNUMBER) {
		threshold_removed = pmax * 2 / 3;
	} else {
		threshold_removed = (int)lua_tointeger(L, -1);
	}
	if (threshold_removed <= 0)
		return luaL_error(L, ".threshold %d is too small", threshold_removed);
	lua_pop(L, 1);
	if (lua_getfield(L, 1, "reserved") != LUA_TNUMBER) {
		threshold_reserved = pmax / 2;
	} else {
		threshold_reserved = (int)lua_tointeger(L, -1);
	}
	if (threshold_reserved < 0)
		return luaL_error(L, ".reserved %d is too small", threshold_reserved);
	if (threshold_reserved > threshold_removed)
		return luaL_error(L, ".reserved %d > .threshold %d", threshold_reserved, threshold_removed);
	lua_pop(L, 1);
	g_man.max = pmax;
	g_man.n = 0;
	g_man.threshold_removed = threshold_removed;
	g_man.threshold_reserved = threshold_reserved;
	g_man.id = 0;
	g_man.frame = 0;
	g_man.removed_n = 0;
	g_man.request = 0;
	return 0;
}

static int
lprogram_new(lua_State *L) {
	if (g_man.id >= PROGRAM_MAX)
		return luaL_error(L, "Too many program id");
	int id = g_man.id++;
	g_man.map[id] = INVALID_HANDLE;
	g_man.timestamp[id] = g_man.frame;
	lua_pushinteger(L, id+1);
	return 1;
}

struct timehandle {
	uint32_t life;
	int id;
};

static int
compar_timehandle(const void *a, const void *b) {
	const struct timehandle *aa = (const struct timehandle *)a;
	const struct timehandle *bb = (const struct timehandle *)b;
	return (int)(bb->life - aa->life);
}

static void
remove_old(struct program_manager *M) {
	int n = 0;
	struct timehandle array[PROGRAM_MAX];
	int i;
	uint32_t current = M->frame;
	for (i=0;i<M->id;i++) {
		if (M->map[i] != INVALID_HANDLE) {
			struct timehandle *h = &array[n++];
			h->life = current - M->timestamp[i];
			h->id = i;
		}
	}
	qsort(array, n, sizeof(struct timehandle), compar_timehandle);
	for (i=0;i<n;i++) {
		if (M->n <= M->threshold_reserved)
			return;
		if (M->removed_n >= REMOVE_MAX)
			return;
		int id = array[i].id;
		uint16_t h = M->map[id];
		M->map[id] = INVALID_HANDLE;
		M->removed[M->removed_n++] = h;
		--M->n;
	}
}

static int
lprogram_set(lua_State *L) {
	int id = checkid(L, 1);
	uint16_t handle = (uint16_t)luaL_checkinteger(L, 2);
	--id;
	if (handle == INVALID_HANDLE)
		return luaL_error(L, "Use reset to set invalid handle");
	if (g_man.map[id] != INVALID_HANDLE)
		return luaL_error(L, "Program id %d is already set", id + 1);
	g_man.map[id] = handle;
	++g_man.n;
	if (g_man.n > g_man.threshold_reserved)
		remove_old(&g_man);
	if (g_man.n + g_man.removed_n > g_man.max)
		return luaL_error(L, "Too many programs in memory");
	return 0;
}

static int
lprogram_reset(lua_State *L) {
	int id = checkid(L, 1);
	--id;
	if (g_man.map[id] == INVALID_HANDLE)
		return 0;
	--g_man.n;
	lua_pushinteger(L, g_man.map[id]);
	g_man.map[id] = INVALID_HANDLE;
	return 1;
}

static int
lprogram_remove(lua_State *L) {
	if (g_man.removed_n == 0)
		return 0;
	lua_settop(L, 1);
	if (lua_isnil(L, 1)) {
		lua_settop(L, 0);
		lua_createtable(L, g_man.removed_n, 0);
	} else {
		luaL_checktype(L, 1, LUA_TTABLE);
	}
	int n = (int)lua_rawlen(L, 1);
	int i;
	for (i=0;i<g_man.removed_n;i++) {
		lua_pushinteger(L, g_man.removed[i]);
		lua_seti(L, 1, n + i + 1);
	}
	g_man.removed_n = 0;
	return 1;
}

static int
lprogram_request(lua_State *L) {
	if (!g_man.request) {
		++g_man.frame;
		return 0;		
	}
	g_man.request = 0;
	lua_settop(L, 1);
	if (lua_isnil(L, 1)) {
		lua_settop(L, 0);
		lua_newtable(L);
	} else {
		luaL_checktype(L, 1, LUA_TTABLE);
	}
	int i;
	uint32_t frame = g_man.frame++;
	int idx = 0;
	for (i=0;i<g_man.id;i++) {
		if (g_man.timestamp[i] == frame && g_man.map[i] == INVALID_HANDLE) {
			lua_pushinteger(L, i+1);
			lua_seti(L, 1, ++idx);
		}
	}
	return 1;
}

static int
lprogram_get(lua_State *L) {
	int id = checkid(L, 1);
	--id;
	uint16_t h = g_man.map[id];
	g_man.timestamp[id] = g_man.frame;
	int luahandle = (BGFX_HANDLE_PROGRAM << 16) | h;
	lua_pushinteger(L, luahandle);
	if (h != INVALID_HANDLE)
		g_man.request = 1;
	return 1;
}

bgfx_program_handle_t
program_get(int id) {
	bgfx_program_handle_t handle = BGFX_INVALID_HANDLE;
	if (id <= 0 || id > g_man.id)
		return handle;
	--id;
	uint16_t h = g_man.map[id];
	g_man.timestamp[id] = g_man.frame;
	handle.idx = h;
	if (h != INVALID_HANDLE)
		g_man.request = 1;
	return handle;
}

LUAMOD_API int
luaopen_programan_client(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "program_get", lprogram_get },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);

	return 1;
}

LUAMOD_API int
luaopen_programan_server(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "program_init", lprogram_init },
		{ "program_new", lprogram_new },
		{ "program_set", lprogram_set },
		{ "program_reset", lprogram_reset },
		{ "program_remove", lprogram_remove },
		{ "program_request", lprogram_request },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);	

	return 1;
}


