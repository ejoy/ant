#define LUA_LIB

#include <lua.h>
#include <lauxlib.h>

#include <string.h>
#include <stdint.h>
#include "math3d.h"
#include "linalg.h"
#include "mathcache.h"
#include "math3dfunc.h"

struct boxcache {
	struct math_cache *c;
};

static int
lnewcache(lua_State *L) {
	struct boxcache * bc = lua_newuserdatauv(L, sizeof(struct boxcache), 0);
	bc->c = mathcache_new();
	if (bc->c == NULL)
		return 0;
	lua_pushvalue(L, lua_upvalueindex(1));
	lua_setmetatable(L, -2);
	return 1;
}

static int
ldeletecache(lua_State *L) {
	struct boxcache *bc = lua_touserdata(L, 1);
	if (bc->c) {
		mathcache_delete(bc->c);
		bc->c = NULL;
	}
	return 0;
}

static inline struct math_cache *
GETMC(lua_State *L) {
	struct boxcache *bc = lua_touserdata(L, 1);
	if (bc == NULL) {
		luaL_error(L, "Need userdata aabb cache");
	}
	return bc->c;
}

static int
lreset(lua_State *L) {
	struct math_cache *MC = GETMC(L);
	struct math_cache_info info;
	mathcache_getinfo(MC, &info);
	mathcache_reset(MC);
	lua_pushinteger(L, info.hit);
	lua_pushinteger(L, info.miss);
	lua_pushinteger(L, info.memsize);
	return 3;
}

static int64_t
get_id(lua_State *L, int index) {
	int type = lua_type(L, index);
	if (type == LUA_TUSERDATA) {
		if (lua_rawlen(L, index) != sizeof(struct refobject))
			luaL_error(L, "Need math refobject at %d", index);
		struct refobject *refobj = lua_touserdata(L, index);
		return refobj->id;
	} else if (type == LUA_TLIGHTUSERDATA) {
		return (int64_t)lua_touserdata(L, index);
	} else {
		return luaL_error(L, "Need math id, it's %s", lua_typename(L, type));
	}
}

static const float *
get_matrix(lua_State *L, struct lastack *LS, int64_t id) {
	int type;
	const float *mat = lastack_value(LS, id, &type);
	if (mat == NULL)
		return NULL;
	if (type != LINEAR_TYPE_MAT)
		luaL_error(L, "Need a matrix");
	return mat;
}

static int
llookup(lua_State *L) {
	struct math_cache *MC = GETMC(L);
	struct lastack *LS  = lua_touserdata(L, lua_upvalueindex(1));
	int64_t worldmat_id;
	struct math_key key = { 0,0 };
	struct math_value *result = NULL;
	struct math_value tmp_result;

	if (lua_type(L, 2) == LUA_TLIGHTUSERDATA ||
		lua_type(L, 3) == LUA_TLIGHTUSERDATA ||
		lua_type(L, 4) == LUA_TLIGHTUSERDATA) {
		result = &tmp_result;
	}
	worldmat_id = get_id(L, 2);
	if (!lua_isnil(L, 3)) {
		key.srt = get_id(L, 3);
	}
	key.aabb = get_id(L, 4);
	if (result || mathcache_lookup(MC, worldmat_id, &key, &result)) {
		// cache miss
		const float *worldmat = get_matrix(L, LS, worldmat_id);
		const float *srt = get_matrix(L, LS, key.srt);
		const float *aabb = get_matrix(L, LS, key.aabb);
		if (srt != NULL) {
			math3d_mul_object(LS, worldmat, srt, LINEAR_TYPE_MAT, LINEAR_TYPE_MAT, result->mat);
			worldmat = result->mat;
			lastack_pushmatrix(LS, result->mat);
			lua_pushlightuserdata(L, (void *)lastack_pop(LS));
		} else {
			// srt is empty, so use worldmat_id
			if (key.srt != 0) {
				// Invalid srt matrix
				memcpy(result->mat, worldmat, 16 * sizeof(float));
			}
			lua_pushlightuserdata(L, (void *)worldmat_id);
		}
		float aabb_result[16];
		math3d_aabb_transform(LS, worldmat, aabb, aabb_result);
		result->minmax[0] = aabb_result[0];
		result->minmax[1] = aabb_result[1];
		result->minmax[2] = aabb_result[2];
		result->minmax[3] = aabb_result[4];
		result->minmax[4] = aabb_result[5];
		result->minmax[5] = aabb_result[6];
	} else {
		// cache hit
		if (key.srt == 0) {
			lua_pushlightuserdata(L, (void *)worldmat_id);
		} else {
			lastack_pushmatrix(LS, result->mat);
			lua_pushlightuserdata(L, (void *)lastack_pop(LS));
		}
	}
	float tmp[16];
	memset(tmp, 0, sizeof(tmp));
	tmp[0] = result->minmax[0];
	tmp[1] = result->minmax[1];
	tmp[2] = result->minmax[2];

	tmp[4] = result->minmax[3];
	tmp[5] = result->minmax[4];
	tmp[6] = result->minmax[5];

	lastack_pushmatrix(LS, tmp);
	lua_pushlightuserdata(L, (void *)lastack_pop(LS));

	return 2;
}

LUAMOD_API int
luaopen_math3d_aabbcache(lua_State *L) {
	luaL_checkversion(L);

	luaL_Reg l[] = {
		{ "new", lnewcache },
		{ NULL, NULL },
	};

	luaL_newlibtable(L, l);

	luaL_Reg cache[] = {
		{ "lookup", NULL },
		{ "reset", lreset },
		{ "__gc", ldeletecache },
		{ "__index", NULL },
		{ NULL, NULL },
	};

	luaL_newlib(L, cache);

	if (lua_getfield(L, LUA_REGISTRYINDEX, MATH3D_STACK) != LUA_TUSERDATA) {
		return luaL_error(L, "request 'math3d' first");
	}
	struct boxstack * bs = lua_touserdata(L, -1);
	lua_pop(L, 1);
	lua_pushlightuserdata(L, bs->LS);
	lua_pushcclosure(L, llookup, 1);
	lua_setfield(L, -2, "lookup");

	// metatable on the top
	lua_pushvalue(L, -1);
	lua_setfield(L, -2, "__index");

	luaL_setfuncs(L, l, 1);

	return 1;
}
