#define LUA_LIB

#include <lua.h>
#include <lauxlib.h>
#include <stdint.h>
#include "math3d.h"

typedef enum {
	SET_Mat = 0x01,
	SET_Vec = 0x02,
	SET_Unknown,
}StackElemType;

static inline struct math3d_api *
math3d_interface(lua_State *L) {
	return (struct math3d_api *)lua_touserdata(L, lua_upvalueindex(1));
}

static inline void *
get_pointer(lua_State *L, struct math3d_api *api, int index, int type) {
	return (void *)math3d_from_lua(L, api, index, type);
}

static void *
getopt_pointer(lua_State *L, struct math3d_api *api, int index, int type) {
	if (lua_isnoneornil(L, index)) {
		return NULL;
	} else {
		return get_pointer(L, api, index, type);
	}
}

static void *
get_pointer_variant(lua_State *L, struct math3d_api *api, int index, int elemtype) {
	if (elemtype & SET_Mat) {
		return get_pointer(L, api, index, MATH_TYPE_MAT);
	} else {
		return get_pointer(L, api, index, MATH_TYPE_VEC4);
	}
}

// upvalue1  mathstack
// upvalue2  cfunction
// upvalue3  from
static int
lmatrix_adapter_1(lua_State *L) {
	struct math3d_api *api = math3d_interface(L);
	lua_CFunction f = lua_tocfunction(L, lua_upvalueindex(2));
	int from = (int)lua_tointeger(L, lua_upvalueindex(3));
	void * v = get_pointer(L, api, from, MATH_TYPE_MAT);
	lua_settop(L, from-1);
	lua_pushlightuserdata(L, v);
	return f(L);
}

static int
lmatrix_adapter_2(lua_State *L) {
	struct math3d_api *api = math3d_interface(L);
	lua_CFunction f = lua_tocfunction(L, lua_upvalueindex(2));
	int from = (int)lua_tointeger(L, lua_upvalueindex(3));
	void * v1 = getopt_pointer(L, api, from, MATH_TYPE_MAT);
	void * v2 = getopt_pointer(L, api, from+1, MATH_TYPE_MAT);
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
	struct math3d_api *api = math3d_interface(L);
	lua_CFunction f = lua_tocfunction(L, lua_upvalueindex(2));
	int from = (int)lua_tointeger(L, lua_upvalueindex(3));
	int i;
	int top = lua_gettop(L);
	for (i=from;i<=top;i++) {
		void * v = getopt_pointer(L, api, i, MATH_TYPE_MAT);
		if (v) {
			lua_pushlightuserdata(L, v);
			lua_replace(L, i);
		}
	}
	return f(L);
}

// upvalue1 : userdata mathstack
// cfunction original function
// integer from 
// integer n
static int
lbind_matrix(lua_State *L) {
	if (!lua_iscfunction(L, 1))
		return luaL_error(L, "need a c function");
	if (lua_getupvalue(L, 1, 1) != NULL)
		luaL_error(L, "Only support light cfunction");
	int from = (int)luaL_checkinteger(L, 2);
	int n = (int)luaL_optinteger(L, 3, 0);
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
	lua_pushvalue(L, lua_upvalueindex(1));
	lua_pushvalue(L, 1);
	lua_pushvalue(L, 2);
	lua_pushinteger(L, from);
	lua_pushcclosure(L, f, 4);
	return 1;
}

static int
lvector(lua_State *L) {
	struct math3d_api *api = math3d_interface(L);
	lua_CFunction f = lua_tocfunction(L, lua_upvalueindex(2));
	const int from = (int)lua_tointeger(L, lua_upvalueindex(3));

	const int top = lua_gettop(L);

	int ii;

	for (ii = from; ii <= top; ++ii) {
		if (!lua_isnil(L, ii)) {
			void* p = get_pointer(L, api, ii, MATH_TYPE_VEC4);
			lua_pushlightuserdata(L, p);
			lua_replace(L, ii);
		}
	}

	return f(L);
}

static int
lbind_vector(lua_State *L) {
	if (!lua_iscfunction(L, 1))
		return luaL_error(L, "need a c function");
	if (lua_getupvalue(L, 1, 1) != NULL)
		luaL_error(L, "Only support light cfunction");

	luaL_checkinteger(L, 2);
	lua_pushvalue(L, lua_upvalueindex(1));
	lua_pushvalue(L, 1);	// cfunction
	lua_pushvalue(L, 2);	// from
	lua_pushcclosure(L, lvector, 3);
	return 1;
}

static uint8_t
check_elem_type(lua_State *L, struct math3d_api *api, int index) {
	if (lua_type(L, index) == LUA_TTABLE) {
		return lua_rawlen(L, index) >= 12 ? SET_Mat : SET_Vec;
	}

	int type;
	math3d_from_lua_id(L, api, index, &type);
	return type == MATH_TYPE_MAT ? SET_Mat : SET_Vec;
}

static void
convert_stack_value(lua_State *L, struct math3d_api *api, int from, int top, int elemtype) {
	int i;
	for (i = from; i <= top; i++) {
		void * v = get_pointer_variant(L, api, i, elemtype);
		if (v) {
			lua_pushlightuserdata(L, v);
			lua_replace(L, i);
		}
	}
}

// upvalue1 mathstack
// upvalue2 matrix cfunction
// upvalue3 vector cfunction
// upvalue4 integer from
static int
lvariant(lua_State *L) {
	struct math3d_api *api = math3d_interface(L);
	const int from = (int)lua_tointeger(L, lua_upvalueindex(4));
	const int top = lua_gettop(L);
	const uint8_t elemtype = check_elem_type(L, api, from);
	lua_CFunction f = lua_tocfunction(L, lua_upvalueindex((elemtype == SET_Mat) ? 2 : 3));
	convert_stack_value(L, api, from, top, elemtype);
	return f(L);
}

// upvalue1 : userdata mathstack
// cfunction original function for matrix
// cfunction original function for vector
// integer from
static int
lbind_variant(lua_State *L) {
	if (!lua_iscfunction(L, 1))
		return luaL_error(L, "need a c function");
	if (lua_getupvalue(L, 1, 1) != NULL)
		luaL_error(L, "Only support light cfunction");
	if (!lua_iscfunction(L, 2))
		return luaL_error(L, "need a c function");
	if (lua_getupvalue(L, 2, 1) != NULL)
		luaL_error(L, "Only support light cfunction");
	luaL_checkinteger(L, 3);

	lua_pushvalue(L, lua_upvalueindex(1));
	lua_pushvalue(L, 1);
	lua_pushvalue(L, 2);
	lua_pushvalue(L, 3);

	lua_pushcclosure(L, lvariant, 4);
	return 1;
}

static int
lformat(lua_State *L, const char *format) {
	struct math3d_api *api = math3d_interface(L);
	lua_CFunction f = lua_tocfunction(L, lua_upvalueindex(2));
	int from = (int)lua_tointeger(L, lua_upvalueindex(4));
	int i;
	int top = lua_gettop(L);
	void *v = NULL;
	for (i=0;format[i];i++) {
		int index = from + i;
		if (index > top)
			luaL_error(L, "Invalid format string %s", format);
		switch(format[i]) {
		case 'm':
			v = get_pointer(L, api, index, MATH_TYPE_MAT);
			break;
		case 'v':
			v = get_pointer(L, api, index, MATH_TYPE_VEC4);
			break;
		case 'q':
			v = get_pointer(L, api, index, MATH_TYPE_QUAT);
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
lformat_function(lua_State *L) {
	lua_CFunction getformat = lua_tocfunction(L, lua_upvalueindex(3));
	if (getformat(L) != 1 || lua_type(L, -1) != LUA_TLIGHTUSERDATA)
		luaL_error(L, "Invalid format C function");
	const char *format = (const char *)lua_touserdata(L, -1);
	lua_pop(L, 1);
	return lformat(L, format);
}

static int
lformat_string(lua_State *L) {
	const char *format = lua_tostring(L, lua_upvalueindex(3));
	return lformat(L, format);
}

// upvalue1: userdata mathstack
// cfunction original function
// cfunction function return (void *)format
// integer from
static int
lbind_format(lua_State *L) {
	if (!lua_iscfunction(L, 1))
		return luaL_error(L, "need a c function");
	if (lua_getupvalue(L, 1, 1) != NULL)
		luaL_error(L, "Only support light cfunction");
	int string_version = 0;
	if (lua_isstring(L, 2)) {
		string_version = 1;
	} else if (!lua_iscfunction(L, 2)) {
		return luaL_error(L, "need a c format function or string");
	}
	if (lua_getupvalue(L, 2, 1) != NULL)
		luaL_error(L, "Only support light cfunction");
	luaL_checkinteger(L, 3);

	lua_pushvalue(L, lua_upvalueindex(1));
	lua_pushvalue(L, 1);
	lua_pushvalue(L, 2);
	lua_pushvalue(L, 3);

	if (string_version) {
		lua_pushcclosure(L, lformat_string, 4);
	} else {
		lua_pushcclosure(L, lformat_function, 4);
	}
	return 1;
}

struct stack_buf {
	float mat[16];
	struct stack_buf *prev;
};

static int
get_n(lua_State *L, int n, struct stack_buf *prev) {
	if (n == 0) {
		struct math3d_api *api = math3d_interface(L);
		lua_CFunction f = lua_tocfunction(L, lua_upvalueindex(2));
		size_t sz = 0;
		const char *format = lua_tolstring(L, lua_upvalueindex(3), &sz);
		int ret = f(L);
		if (ret == 0) {
			lua_settop(L, 0);
		} else {
			int top = lua_gettop(L);
			if (ret != top) {
				if (ret < top && ret != 0) {
					int remove = top-ret;
					lua_rotate(L, 1, -remove);
				}
				lua_settop(L, ret);
			}
		}
		luaL_checkstack(L, (int)sz, NULL);
		int i = (int)sz - 1;
		int type;
		while (prev) {
			switch(format[i]) {
			case 'm':
				type = MATH_TYPE_MAT;
				break;
			case 'v':
				type = MATH_TYPE_VEC4;
				break;
			case 'q':
				type = MATH_TYPE_QUAT;
				break;
			default:
				type = MATH_TYPE_NULL;
				luaL_error(L,"Invalid getter format %s", format);
				break;
			}
			math3d_push(L, api, prev->mat, type);
			lua_insert(L, ret+1);

			prev = prev->prev;
			--i;
		}
		return ret + (int)sz;
	}
	struct stack_buf buf;
	buf.prev = prev;
	lua_pushlightuserdata(L, (void *)buf.mat);
	return get_n(L, n-1, &buf);
}

static int
lgetter(lua_State *L) {
	size_t n = 0;
	lua_tolstring(L, lua_upvalueindex(3), &n);
	luaL_checkstack(L, (int)(n + LUA_MINSTACK), NULL);
	return get_n(L, (int)n, NULL);
}

// upvalue1 : userdata mathstack
// cfunction original getter
// string format "mvq" , m for matrix, v for vector4, q for quat
static int
lbind_getter(lua_State *L) {
	if (!lua_iscfunction(L, 1))
		return luaL_error(L, "need a c function");
	luaL_checkstring(L, 2);
	lua_pushvalue(L, lua_upvalueindex(1));
	lua_pushvalue(L, 1);
	lua_pushvalue(L, 2);
	lua_pushcclosure(L, lgetter, 3);
	return 1;
}

static int
loutput_object(lua_State *L, int ltype) {
	lua_CFunction f = lua_tocfunction(L, lua_upvalueindex(2));
	int retn = f(L);
	int from = (int)lua_tointeger(L, lua_upvalueindex(3));
	int top = lua_gettop(L);
	if (retn > from) {
		lua_settop(L, retn);
		top = retn;
	}
	from = top - retn + from;
	int i;
	struct math3d_api *api = math3d_interface(L);

	for (i=from;i<=top;i++) {
		if (lua_type(L, i) != LUA_TLIGHTUSERDATA) {
			return luaL_error(L, "ret %d should be a lightuserdata", i);
		}
		const float *v = (const float *)lua_touserdata(L, i);
		math3d_push(L, api, v, ltype);
		lua_replace(L, i);
	}
	return retn;
}

static int
loutput_matrix(lua_State *L) {
	return loutput_object(L, MATH_TYPE_MAT);
}

static int
loutput_vector(lua_State *L) {
	return loutput_object(L, MATH_TYPE_VEC4);
}

static int
loutput_quat(lua_State *L) {
	return loutput_object(L, MATH_TYPE_QUAT);
}

// upvalue1 : userdata mathstack
// cfunction original output
// integer from
static int
lbind_output(lua_State *L, lua_CFunction output_func) {
	if (!lua_iscfunction(L, 1))
		return luaL_error(L, "need a c function");
	luaL_checkinteger(L, 2);
	lua_pushvalue(L, lua_upvalueindex(1));
	lua_pushvalue(L, 1);
	lua_pushvalue(L, 2);
	lua_pushcclosure(L, output_func, 3);
	return 1;
}

static int
lbind_output_matrix(lua_State *L) {
	return lbind_output(L, loutput_matrix);
}

static int
lbind_output_vector(lua_State *L) {
	return lbind_output(L, loutput_vector);
}

static int
lbind_output_quat(lua_State *L) {
	return lbind_output(L, loutput_quat);
}

LUAMOD_API int
luaopen_math3d_adapter(lua_State *L) {
	luaL_checkversion(L);
	
	luaL_Reg l[] = {
		{ "matrix", lbind_matrix },
		{ "vector", lbind_vector},
		{ "variant", lbind_variant },
		{ "format", lbind_format },
		{ "getter", lbind_getter },
		{ "output_matrix", lbind_output_matrix },
		{ "output_vector", lbind_output_vector },
		{ "output_quat", lbind_output_quat },
		{ NULL, NULL },
	};

	luaL_newlibtable(L, l);

	if (lua_getfield(L, LUA_REGISTRYINDEX, MATH3D_CONTEXT) != LUA_TUSERDATA) {
		return luaL_error(L, "request 'math3d' first");
	}
	struct math3d_api * api = lua_touserdata(L, -1);
	lua_pop(L, 1);
	lua_pushlightuserdata(L, api);

	luaL_setfuncs(L,l,1);

	return 1;
}
