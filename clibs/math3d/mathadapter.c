#define LUA_LIB

#include <lua.h>
#include <lauxlib.h>
#include <stdint.h>
#include "math3d.h"
#include "linalg.h"

static const char * linear_type[] = {
	"MAT",
	"VEC4",
	"NUM",
	"QUAT",
	"EULER",
};

static const char *
linear_typename(int t) {
	if (t<0 || t>= LINEAR_TYPE_COUNT) {
		return "UNKNOWN";
	} else {
		return linear_type[t];
	}
}

static void
typemismatch(lua_State *L, int t1, int t2) {
	luaL_error(L, "Type mismatch, need %s, it's %s", linear_typename(t1), linear_typename(t2));
}

static void *
get_pointer(lua_State *L, struct lastack *LS, int index, int type) {
	int t;
	float *v;
	if (lua_isinteger(L, index)) {
		int64_t id = lua_tointeger(L, index);
		v = lastack_value(LS, id, &t);
	} else {
		struct refobject * ref = (struct refobject *)luaL_checkudata(L, index, LINALG_REF);
		if (ref->LS != NULL && ref->LS != LS) {
			luaL_error(L, "Math stack mismatch");
		}
		v = lastack_value(LS, ref->id, &t);
	}
	if (type != t) {
		typemismatch(L, type, t);
	}
	return v;
}

static void *
getopt_pointer(lua_State *L, struct lastack *LS, int index, int type) {
	if (lua_isnoneornil(L, index)) {
		return NULL;
	} else {
		return get_pointer(L, LS, index, type);
	}
}

static void *
get_pointer_type(lua_State *L, struct lastack *LS, int index, int *type) {
	float *v;
	if (lua_isinteger(L, index)) {
		int64_t id = lua_tointeger(L, index);
		v = lastack_value(LS, id, type);
	} else {
		struct refobject * ref = (struct refobject *)luaL_checkudata(L, index, LINALG_REF);
		if (ref->LS != NULL && ref->LS != LS) {
			luaL_error(L, "Math stack mismatch");
		}
		v = lastack_value(LS, ref->id, type);
	}
	return v;
}

static void *
get_pointer_variant(lua_State *L, struct lastack *LS, int index, int ismatrix) {
	int type;
	float *v;
	if (lua_isinteger(L, index)) {
		int64_t id = lua_tointeger(L, index);
		v = lastack_value(LS, id, &type);
	} else if (lua_istable(L, index)) {
		return NULL;
	} else {
		struct refobject * ref = (struct refobject *)luaL_checkudata(L, index, LINALG_REF);
		if (ref->LS != NULL && ref->LS != LS) {
			luaL_error(L, "Math stack mismatch");
		}
		v = lastack_value(LS, ref->id, &type);
	}
	if (type == LINEAR_TYPE_MAT) {
		if (!ismatrix)
			typemismatch(L, LINEAR_TYPE_MAT, type);
	} else {
		if (ismatrix)
			typemismatch(L, LINEAR_TYPE_VEC4, type);
	}
	return v;
}

// upvalue1  mathstack
// upvalue2  cfunction
// upvalue3  from
// 2 mathid or mathuserdata LINALG_REF
static int
lmatrix_adapter_1(lua_State *L) {
	struct boxstack *bp = lua_touserdata(L, lua_upvalueindex(1));
	lua_CFunction f = lua_tocfunction(L, lua_upvalueindex(2));
	int from = lua_tointeger(L, lua_upvalueindex(3));
	void * v = get_pointer(L, bp->LS, from, LINEAR_TYPE_MAT);
	lua_settop(L, from-1);
	lua_pushlightuserdata(L, v);
	return f(L);
}

static int
lmatrix_adapter_2(lua_State *L) {
	struct boxstack *bp = lua_touserdata(L, lua_upvalueindex(1));
	lua_CFunction f = lua_tocfunction(L, lua_upvalueindex(2));
	int from = lua_tointeger(L, lua_upvalueindex(3));
	void * v1 = getopt_pointer(L, bp->LS, from, LINEAR_TYPE_MAT);
	void * v2 = getopt_pointer(L, bp->LS, from+1, LINEAR_TYPE_MAT);
	lua_settop(L, from-1);
	if (v1) {
		lua_pushlightuserdata(L, v1);
	} else {
		lua_pushnil(L);
	}
	if (v2) {
		lua_pushlightuserdata(L, v2);
	} else {
		lua_pushnil(L);
	}
	return f(L);
}

static int
lmatrix_adapter_var(lua_State *L) {
	struct boxstack *bp = lua_touserdata(L, lua_upvalueindex(1));
	lua_CFunction f = lua_tocfunction(L, lua_upvalueindex(2));
	int from = lua_tointeger(L, lua_upvalueindex(3));
	int i;
	int top = lua_gettop(L);
	struct lastack *LS = bp->LS;
	for (i=from;i<=top;i++) {
		void * v = getopt_pointer(L, LS, i, LINEAR_TYPE_MAT);
		if (v) {
			lua_pushlightuserdata(L, v);
			lua_replace(L, i);
		}
	}
	return f(L);
}

// userdata mathstack
// cfunction original function
// integer from 
// integer n
static int
lbind_matrix(lua_State *L) {
	luaL_checkudata(L, 1, LINALG);
	if (!lua_iscfunction(L, 2))
		return luaL_error(L, "need a c function");
	if (lua_getupvalue(L, 2, 1) != NULL)
		luaL_error(L, "Only support light cfunction");
	int from = luaL_checkinteger(L, 3);
	int n = luaL_optinteger(L, 4, 0);
	lua_CFunction f;
	switch (n) {
	case 0:
		f = lmatrix_adapter_var;
		break;
	case 1:
		f = lmatrix_adapter_1;
		break;
	case 2:
		f = lmatrix_adapter_2;
		break;
	default:
		return luaL_error(L, "Only support 1,2,0(vararg) now");
	}
	lua_settop(L, 2);
	lua_pushinteger(L, from);
	lua_pushcclosure(L, f, 3);
	return 1;
}

// upvalue1 mathstack
// upvalue2 matrix cfunction
// upvalue3 vector cfunction
// upvalue4 integer from
static int
lvariant(lua_State *L) {
	struct boxstack *bp = lua_touserdata(L, lua_upvalueindex(1));
	struct lastack *LS = bp->LS;
	int from = lua_tointeger(L, lua_upvalueindex(4));
	int ismatrix;
	if (lua_type(L, from) == LUA_TTABLE) {
		ismatrix = lua_rawlen(L, from) >= 12;
	} else {
		int type;
		void *v = get_pointer_type(L, LS, from, &type);
		ismatrix = (type == LINEAR_TYPE_MAT);
		lua_pushlightuserdata(L, v);
		lua_replace(L, from);
	}
	lua_CFunction f = lua_tocfunction(L, lua_upvalueindex(ismatrix ? 2 : 3));

	int i;
	int top = lua_gettop(L);

	for (i=from+1;i<=top;i++) {
		void * v = get_pointer_variant(L, LS, i, ismatrix);
		if (v) {
			lua_pushlightuserdata(L, v);
			lua_replace(L, i);
		}
	}

	return f(L);
}

// userdata mathstack
// cfunction original function for matrix
// cfunction original function for vector
// integer from
static int
lbind_variant(lua_State *L) {
	luaL_checkudata(L, 1, LINALG);
	if (!lua_iscfunction(L, 2))
		return luaL_error(L, "need a c function");
	if (lua_getupvalue(L, 2, 1) != NULL)
		luaL_error(L, "Only support light cfunction");
	if (!lua_iscfunction(L, 3))
		return luaL_error(L, "need a c function");
	if (lua_getupvalue(L, 3, 1) != NULL)
		luaL_error(L, "Only support light cfunction");
	luaL_checkinteger(L, 4);
	lua_settop(L, 4);
	lua_pushcclosure(L, lvariant, 4);
	return 1;
}

static int
lformat(lua_State *L) {
	struct boxstack *bp = lua_touserdata(L, lua_upvalueindex(1));
	struct lastack *LS = bp->LS;
	lua_CFunction f = lua_tocfunction(L, lua_upvalueindex(2));
	lua_CFunction getformat = lua_tocfunction(L, lua_upvalueindex(3));
	int from = lua_tointeger(L, lua_upvalueindex(4));
	if (getformat(L) != 1 || lua_type(L, -1) != LUA_TLIGHTUSERDATA)
		luaL_error(L, "Invalid format C function");
	const char *format = (const char *)lua_touserdata(L, -1);
	lua_pop(L, 1);
	int i;
	int top = lua_gettop(L);
	int type;
	void *v;
	for (i=0;format[i];i++) {
		int index = from + i;
		if (index > top)
			luaL_error(L, "Invalid format string %s", format);
		v = get_pointer_type(L, LS, index, &type);
		switch(format[i]) {
		case 'm':
			if (type != LINEAR_TYPE_MAT) {
				typemismatch(L, LINEAR_TYPE_MAT, type);
			}
			break;
		case 'v':
			if (type == LINEAR_TYPE_MAT) {
				typemismatch(L, LINEAR_TYPE_VEC4, type);
			}
			break;
		default:
			luaL_error(L, "Invalid format string %s", format);
			break;
		}
		lua_pushlightuserdata(L, v);
		lua_replace(L, index);
	}
	return f(L);
}

static int
lbind_format(lua_State *L) {
	luaL_checkudata(L, 1, LINALG);
	if (!lua_iscfunction(L, 2))
		return luaL_error(L, "need a c function");
	if (lua_getupvalue(L, 2, 1) != NULL)
		luaL_error(L, "Only support light cfunction");
	if (!lua_iscfunction(L, 3))
		return luaL_error(L, "need a c function");
	if (lua_getupvalue(L, 3, 1) != NULL)
		luaL_error(L, "Only support light cfunction");
	luaL_checkinteger(L, 4);
	lua_settop(L, 4);
	lua_pushcclosure(L, lformat, 4);
	return 1;
}

// userdata mathstack
// cfunction original function for varient
// cfunction function for format
// integer from
LUAMOD_API int
luaopen_math3d_adapter(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "matrix", lbind_matrix },
		{ "variant", lbind_variant },
		{ "format", lbind_format },
		{ NULL, NULL },
	};

	luaL_newlib(L, l);

	return 1;
}
