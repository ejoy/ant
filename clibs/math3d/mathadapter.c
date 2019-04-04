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

typedef enum {
	SET_Mat = 0x01,
	SET_Vec = 0x02,
	SET_Array = 0x10,
	SET_Unknown,
}StackElemType;

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
	const float *v;
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
	return (void *)v;
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
	const float *v;
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
	return (void *)v;
}

static void *
get_pointer_variant(lua_State *L, struct lastack *LS, int index, int elemtype) {
	int type;
	const float *v;
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
		if (!(elemtype & SET_Mat))
			typemismatch(L, LINEAR_TYPE_MAT, type);
	} else {
		if (elemtype & SET_Mat)
			typemismatch(L, LINEAR_TYPE_VEC4, type);
	}
	return (void *)v;
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

static int
lvector(lua_State *L) {
	struct boxstack *bp = lua_touserdata(L, lua_upvalueindex(1));
	struct lastack *LS = bp->LS;
	lua_CFunction f = lua_tocfunction(L, lua_upvalueindex(2));
	const int from = lua_tointeger(L, lua_upvalueindex(3));

	const int top = lua_gettop(L);

	for (int ii = from; ii <= top; ++ii) {
		if (!lua_isnil(L, ii)) {
			int type;
			void* p = get_pointer_type(L, LS, ii, &type);
			if (p == NULL) {
				luaL_error(L, "arg index:%d, could not convert to light userdata with math3d stack object", ii);
			}

			lua_pushlightuserdata(L, p);
			lua_replace(L, ii);
		}
	}

	return f(L);
}

static int
lbind_vector(lua_State *L) {
	luaL_checkudata(L, 1, LINALG);
	if (!lua_iscfunction(L, 2))
		return luaL_error(L, "need a c function");
	if (lua_getupvalue(L, 2, 1) != NULL)
		luaL_error(L, "Only support light cfunction");

	luaL_checkinteger(L, 3);
	lua_settop(L, 3);
	lua_pushcclosure(L, lvector, 3);
	return 1;
}

static int
get_type(lua_State *L, struct lastack* LS, int index) {
	int64_t id = get_stack_id(L, LS, index);
	return lastack_type(LS, id);
}


static uint8_t
check_elem_type(lua_State *L, struct lastack *LS, int index) {	
	if (lua_type(L, index) == LUA_TTABLE) {
		const int fieldtype = lua_getfield(L, index, "n");	
		lua_pop(L, 1);

		if (fieldtype != LUA_TNIL){
			const int elemtype = lua_geti(L, index, 1);			
			if (elemtype != LUA_TTABLE) {
				int type = get_type(L, LS, -1);
				lua_pop(L, 1);
				return SET_Array | (type == LINEAR_TYPE_MAT ? SET_Mat : SET_Vec);
			} 

			lua_pop(L, 1);
			return SET_Array | (lua_rawlen(L, index) >= 12 ? SET_Mat : SET_Vec);
		}
		return lua_rawlen(L, index) >= 12 ? SET_Mat : SET_Vec;
	}

	int type;
	get_pointer_type(L, LS, index, &type);
	return type == LINEAR_TYPE_MAT ? SET_Mat : SET_Vec;
}

static void
unpack_table_on_stack(lua_State *L, struct lastack *LS, int from, int top, int elemtype) {
	for (int stackidx = from; stackidx <= top; ++stackidx) {
		if (lua_getfield(L, stackidx, "n") != LUA_TNIL) {
			const int num = (int)lua_tointeger(L, -1);
			lua_pop(L, 1);	// pop 'n'	

			const int tablenum = (int)lua_rawlen(L, stackidx);
			if (num != tablenum) {
				luaL_error(L, "'n' field: %d not equal to table count: %d", num, tablenum);
			}

			for (int tblidx = 0; tblidx < num; ++tblidx) {
				lua_geti(L, stackidx, tblidx + 1);				
				void * v = get_pointer_variant(L, LS, -1, elemtype);
				if (v) {
					lua_pop(L, 1);	// pop lua_geti value
					lua_pushlightuserdata(L, v);
				} else {
					luaL_checktype(L, -1, LUA_TTABLE);
				}

				// v == NULL will not pop, make it in the stack
			}
		}
	}

	for (int ii = 0; ii <= top - from; ++ii) {
		lua_remove(L, from);
	}
}

static void
convert_stack_value(lua_State *L, struct lastack *LS, int from, int top, int elemtype) {
	for (int i = from; i <= top; i++) {
		void * v = get_pointer_variant(L, LS, i, elemtype);
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
	struct boxstack *bp = lua_touserdata(L, lua_upvalueindex(1));
	struct lastack *LS = bp->LS;
	const int from = lua_tointeger(L, lua_upvalueindex(4));
	const int top = lua_gettop(L);
	const uint8_t elemtype = check_elem_type(L, LS, from);	
	lua_CFunction f = lua_tocfunction(L, lua_upvalueindex((elemtype & SET_Mat) ? 2 : 3));
	if (elemtype & SET_Array) {
		unpack_table_on_stack(L, LS, from, top, elemtype);
	} else {		
		convert_stack_value(L, LS, from, top, elemtype);
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
		{ "vector", lbind_vector},
		{ "variant", lbind_variant },
		{ "format", lbind_format },
		{ NULL, NULL },
	};

	luaL_newlib(L, l);

	return 1;
}
