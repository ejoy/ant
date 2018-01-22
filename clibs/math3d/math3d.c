#define LUA_LIB

#include <lua.h>
#include <lauxlib.h>
#include <inttypes.h>
#include <assert.h>
#include "linalg.h"

#define LINALG "LINALG"

struct boxpointer {
	struct lastack *LS;
};

static struct lastack *
getLS(lua_State *L, int index) {
	luaL_checktype(L, index, LUA_TFUNCTION);
	if (lua_getupvalue(L, index, 1) == NULL) {
		luaL_error(L, "Can't get linalg object");
	}
	struct boxpointer * ret = luaL_checkudata(L, -1, LINALG);
	lua_pop(L, 1);
	return ret->LS;
}

static int
delLS(lua_State *L) {
	struct boxpointer *bp = lua_touserdata(L, 1);
	if (bp->LS) {
		lastack_delete(bp->LS);
		bp->LS = NULL;
	}
	return 0;
}

static void
push_value(lua_State *L, struct lastack *LS, int index) {
	int n = lua_rawlen(L, index);
	int i;
	float v[16];
	if (n > 16) {
		luaL_error(L, "Invalid value %d", n);
	}
	luaL_checkstack(L, n, NULL);
	for (i=0;i<n;i++) {
		lua_geti(L, index, i+1);
		v[i] = lua_tonumber(L, -1);
		lua_pop(L,1);
	}
	switch (n) {
	case 3:
		// vector 3
		v[3] = 1.0f;
	case 4:
		lastack_pushvector(LS, v);
		break;
	case 16:
		lastack_pushmatrix(LS, v);
		break;
	default:
		luaL_error(L, "Invalid value %d", n);
	}
}

static inline void
pushid(lua_State *L, int64_t v) {
	if (sizeof(lua_Integer) >= sizeof(int64_t)) {
		lua_pushinteger(L, v);
	} else {
		lua_pushnumber(L, (lua_Number)v);
	}
}

static void
add_value(lua_State *L, struct lastack *LS) {
	int64_t v1 = lastack_pop(LS);
	int64_t v2 = lastack_pop(LS);
	if (v1 == 0 || v2 == 0)
		luaL_error(L, "No 2 values");
	int s1,s2;
	float *val1 = lastack_value(LS, v1, &s1);
	float *val2 = lastack_value(LS, v2, &s2);
	if (s1 != s2)
		luaL_error(L, "type mismatch");
	if (s1 == 4) {
		float ret[4];
		ret[0] = val1[0] + val2[0];
		ret[1] = val1[1] + val2[1];
		ret[2] = val1[2] + val2[2];
		ret[3] = val1[3] + val2[3];
		lastack_pushvector(LS, ret);
	} else {
		assert(s1 == 16);
		float ret[16];
		int i;
		for (i=0;i<16;i++) {
			ret[i] = val1[i] + val2[i];
		}
		lastack_pushmatrix(LS, ret);
	}
}

/*
	P : pop and return id
	V : pop and return pointer
	D : dup stack top
	R : remove stack top
	M : mark stack top and pop
 */
static int
do_command(lua_State *L, struct lastack *LS, char cmd) {
	int64_t v = 0;
	switch (cmd) {
	case 'P':
		v = lastack_pop(LS);
		if (v == 0)
			luaL_error(L, "pop empty stack");
		pushid(L, v);
		return 1;
	case 'V':
		v = lastack_pop(LS);
		if (v == 0)
			luaL_error(L, "pop empty stack");
		lua_pushlightuserdata(L, lastack_value(LS, v, NULL));
		return 1;
	case 'T': {
		v = lastack_pop(LS);
		if (v == 0)
			luaL_error(L, "pop empty stack");
		int sz;
		float * val = lastack_value(LS, v, &sz);
		lua_createtable(L, sz, 0);
		int i;
		for (i=0;i<sz;i++) {
			lua_pushnumber(L, val[i]);
			lua_seti(L, -2, i+1);
		}
		return 1;
	}
	case 'D':
		v = lastack_dup(LS);
		if (v == 0)
			luaL_error(L, "dup empty stack");
		break;
	case 'R':
		v = lastack_pop(LS);
		if (v == 0)
			luaL_error(L, "remove empty stack");
		break;
	case 'M':
		v = lastack_mark(LS);
		if (v == 0)
			luaL_error(L, "mark empty stack or too many marked values");
		pushid(L, v);
		return 1;
	case '+':
		add_value(L, LS);
		return 0;
	}
	return 0;
}

static int
push_command(lua_State *L, struct lastack *LS, int index) {
	int type = lua_type(L, index);
	switch(type) {
	case LUA_TTABLE:
		push_value(L, LS, index);
		break;
	case LUA_TNUMBER: {
		int64_t v;
		if (sizeof(lua_Integer) >= sizeof(int64_t)) {
			v = lua_tointeger(L, index);
		} else {
			v = (int64_t)lua_tonumber(L, index);
		}
		if (lastack_pushref(LS, v)) {
			return luaL_error(L, "Invalid id %I", v);
		}
		break;
	}
	case LUA_TSTRING: {
		size_t sz;
		const char * cmd = luaL_checklstring(L, index, &sz);
		luaL_checkstack(L, sz + 20, NULL);
		int i;
		int ret = 0;
		for (i=0;i<(int)sz;i++) {
			ret += do_command(L, LS, cmd[i]);
		}
		return ret;
	}
	default:
		return luaL_error(L, "Invalid command type %s at %d", lua_typename(L, type), index);
	}
	return 0;
}

static int
commandLS(lua_State *L) {
	struct boxpointer *bp = lua_touserdata(L, lua_upvalueindex(1));
	struct lastack *LS = bp->LS;
	int top = lua_gettop(L);
	int i;
	int ret = 0;
	for (i=1;i<=top;i++) {
		ret += push_command(L, LS, i);
	}
	return ret;
}

static int
lnew(lua_State *L) {
	struct boxpointer *bp = lua_newuserdata(L, sizeof(*bp));
	bp->LS = NULL;
	if (luaL_newmetatable(L, LINALG)) {
		lua_pushcfunction(L, delLS);
		lua_setfield(L, -2, "__gc");
	}
	lua_setmetatable(L, -2);
	lua_pushcclosure(L, commandLS, 1);
	bp->LS = lastack_new();
	return 1;
}

static int
lreset(lua_State *L) {
	struct lastack *LS = getLS(L, 1);
	lastack_reset(LS);
	return 0;
}

static int
lprint(lua_State *L) {
	struct lastack *LS = getLS(L, 1);
	lastack_print(LS);
	return 0;
}

LUAMOD_API int
luaopen_math3d(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "new", lnew },
		{ "reset", lreset },
		{ "print", lprint },	// for debug
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}
