#pragma once

#include <lua.hpp>
#include "lua_compat.h"
#include "rlua.h"
#include "rdebug_table.h"
#include <stdint.h>
#include <string.h>

/*
	TYPE            frame (16bit)      index (32bit)      size
	-----------------------------------------------------------
	VAR_FRAME_LOCAL stack frame        index              1
	VAR_FRAME_FUNC  stack frame        -                  1
	VAR_INDEX       0/1 (*)            index              ?
	VAR_INDEX_OBJ   0/1 (*)            size of table      ?
	VAR_UPVALUE     -                  index              ?
	VAR_GLOBAL      -                  -                  1
	VAR_REGISTRY    -                  -                  1
	VAR_METATABLE   0/1 (**)           - (lua type)       ?/1
	VAR_USERVALUE   -                  -                  ?

	* : 0 indexed value, 1 next key
	** : 0 metatable of object ; 1 metatable of lua type
*/

#define VAR_FRAME_LOCAL 0	// stack(frame, index)
#define VAR_FRAME_FUNC 1 // stack(frame).func
#define VAR_INDEX  2	// table[const key]
#define VAR_INDEX_OBJ 3	// table[object key]
#define VAR_UPVALUE 4	// func[index]
#define VAR_GLOBAL 5	// _G
#define VAR_REGISTRY 6	// REGISTRY
#define VAR_METATABLE 8	// table.metatable
#define VAR_USERVALUE 9	// userdata.uservalue
#define VAR_STACK 10
#define VAR_INDEX_KEY 11
#define VAR_INDEX_VAL 12
#define VARKEY_INDEX 0
#define VARKEY_NEXT 1

struct value {
	uint8_t type;
	uint16_t frame;
	int index;
};

// return record number of value 
static int
sizeof_value(struct value *v) {
	switch (v->type) {
	case VAR_FRAME_LOCAL:
	case VAR_FRAME_FUNC:
	case VAR_GLOBAL:
	case VAR_REGISTRY:
	case VAR_STACK:
		return 1;
	case VAR_INDEX_OBJ:
		return 1 + v->index + sizeof_value(v+1+v->index);
	case VAR_METATABLE:
		if (v->frame) {
			return 1;
		}
		// go through
	case VAR_INDEX:
	case VAR_UPVALUE:
	case VAR_USERVALUE:
	case VAR_INDEX_KEY:
	case VAR_INDEX_VAL:
		return 1 + sizeof_value(v+1);
	}
	return 0;
}

// copy a value from -> to, return the lua type of copied or LUA_TNONE
static int
copy_toX(lua_State *from, rlua_State *to) {
	int t = lua_type(from, -1);
	switch(t) {
	case LUA_TNIL:
		rlua_pushnil(to);
		break;
	case LUA_TBOOLEAN:
		rlua_pushboolean(to, lua_toboolean(from,-1));
		break;
	case LUA_TNUMBER:
#if LUA_VERSION_NUM >= 503
		if (lua_isinteger(from, -1)) {
			rlua_pushinteger(to, lua_tointeger(from, -1));
		} else {
			rlua_pushnumber(to, lua_tonumber(from, -1));
		}
#else
		rlua_pushnumber(to, lua_tonumber(from, -1));
#endif
		break;
	case LUA_TSTRING: {
		size_t sz;
		const char *str = lua_tolstring(from, -1, &sz);
		rlua_pushlstring(to, str, sz);
		break;
		}
	case LUA_TLIGHTUSERDATA:
		rlua_pushlightuserdata(to, lua_touserdata(from, -1));
		break;
	default:
		return LUA_TNONE;
	}
	return t;
}

static int
copy_fromX(rlua_State *from, lua_State *to) {
	int t = rlua_type(from, -1);
	switch(t) {
	case LUA_TNIL:
		lua_pushnil(to);
		break;
	case LUA_TBOOLEAN:
		lua_pushboolean(to, rlua_toboolean(from,-1));
		break;
	case LUA_TNUMBER:
		if (rlua_isinteger(from, -1)) {
			lua_pushinteger(to, (lua_Integer)rlua_tointeger(from, -1));
		} else {
			lua_pushnumber(to, rlua_tonumber(from, -1));
		}
		break;
	case LUA_TSTRING: {
		size_t sz;
		const char *str = rlua_tolstring(from, -1, &sz);
		lua_pushlstring(to, str, sz);
		break;
		}
	case LUA_TLIGHTUSERDATA:
		lua_pushlightuserdata(to, rlua_touserdata(from, -1));
		break;
	default:
		return LUA_TNONE;
	}
	return t;
}

void
copyvalue(lua_State *from, rlua_State *to) {
	if (copy_toX(from, to) == LUA_TNONE) {
		rlua_pushfstring(to, "[%s: %p]",
			lua_typename(from, lua_type(from, -1)),
			lua_topointer(from, -1)
		);
	}
}

// L top : value, uservalue
static int
eval_value_(rlua_State *L, lua_State *cL, struct value *v) {
	if (lua_checkstack(cL, 3) == 0)
		return rluaL_error(L, "stack overflow");

	switch (v->type) {
	case VAR_FRAME_LOCAL: {
		lua_Debug ar;
		if (lua_getstack(cL, v->frame, &ar) == 0)
			break;
		const char * name = lua_getlocal(cL, &ar, v->index);
		if (name) {
			return lua_type(cL, -1);
		}
		break;
	}
	case VAR_FRAME_FUNC: {
		lua_Debug ar;
		if (lua_getstack(cL, v->frame, &ar) == 0)
			break;
		if (lua_getinfo(cL, "f", &ar) == 0)
			break;
		return LUA_TFUNCTION;
	}
	case VAR_INDEX:
	case VAR_INDEX_OBJ: {
		int t = eval_value_(L, cL, v+1);
		if (t == LUA_TNONE)
			break;
		if (t != LUA_TTABLE) {
			// only table can be index
			lua_pop(cL, 1);
			break;
		}
		if (v->type == VAR_INDEX) {
			if (v->index == 0) {
				rlua_pushnil(L);
			} else {
				rlua_rawgeti(L, -1, v->index);
			}
			if (copy_fromX(L, cL) == LUA_TNONE) {
				rlua_pop(L, 1);
				lua_pop(cL, 1);
				break;
			}
			rlua_pop(L, 1);	// pop key
		} else {
			if (eval_value_(L, cL, v+1+v->index) == LUA_TNONE) {
				lua_pop(cL, 1);	// pop table
				break;
			}
		}
		if (v->frame == 0) {
			// index key
			lua_rawget(cL, -2);
			lua_replace(cL, -2);
			return lua_type(cL, -1);
		} else {
			// next key
			if (lua_next(cL, -2) == 0) {
				lua_pop(cL, 1);	// pop table
				break;
			}
			lua_pop(cL, 1);	// pop value
			lua_replace(cL, -2);
			return lua_type(cL, -1);
		}
	}
	case VAR_INDEX_KEY:
	case VAR_INDEX_VAL: {
		int t = eval_value_(L, cL, v+1);
		if (t == LUA_TNONE)
			break;
		if (t != LUA_TTABLE) {
			// only table can be index
			lua_pop(cL, 1);
			break;
		}
		bool ok = v->type == VAR_INDEX_KEY
			? remotedebug::table::get_k(cL, -1, v->index)
			: remotedebug::table::get_v(cL, -1, v->index)
			;
		if (!ok) {
			lua_pop(cL, 1);
			break;
		}
		lua_remove(cL, -2);
		return lua_type(cL, -1);
	}
	case VAR_UPVALUE: {
		int t = eval_value_(L, cL, v+1);
		if (t == LUA_TNONE)
			break;
		if (t != LUA_TFUNCTION) {
			// only function has upvalue
			lua_pop(cL, 1);
			break;
		}
		if (lua_getupvalue(cL, -1, v->index)) {
			lua_replace(cL, -2);	// remove function
			return lua_type(cL, -1);
		} else {
			rlua_pop(L, 1);
			break;
		}
	}
	case VAR_GLOBAL:
#if LUA_VERSION_NUM == 501
		lua_pushvalue(cL, LUA_GLOBALSINDEX);
		return LUA_TTABLE;
#else
		return lua::rawgeti(cL, LUA_REGISTRYINDEX, LUA_RIDX_GLOBALS);
#endif
	case VAR_REGISTRY:
		lua_pushvalue(cL, LUA_REGISTRYINDEX);
		return LUA_TTABLE;
	case VAR_METATABLE:
		if (v->frame == 1) {
			switch(v->index) {
			case LUA_TNIL:
				lua_pushnil(cL);
				break;
			case LUA_TBOOLEAN:
				lua_pushboolean(cL, 0);
				break;
			case LUA_TNUMBER:
				lua_pushinteger(cL, 0);
				break;
			case LUA_TSTRING:
				lua_pushstring(cL, "");
				break;
			case LUA_TLIGHTUSERDATA:
				lua_pushlightuserdata(cL, NULL);
				break;
			default:
				return LUA_TNONE;
			}
		} else {
			int t = eval_value_(L, cL, v+1);
			if (t == LUA_TNONE)
				break;
			if (t != LUA_TTABLE && t != LUA_TUSERDATA) {
				lua_pop(cL, 1);
				break;
			}
		}
		if (lua_getmetatable(cL, -1)) {
			lua_replace(cL, -2);
			return LUA_TTABLE;
		} else {
			lua_pop(cL, 1);
			lua_pushnil(cL);
			return LUA_TNIL;
		}
	case VAR_USERVALUE: {
		int t = eval_value_(L, cL, v+1);
		if (t == LUA_TNONE)
			break;
		if (t != LUA_TUSERDATA) {
			lua_pop(cL, 1);
			break;
		}
		t = lua::getuservalue(cL, -1);
		lua_replace(cL, -2);
		return t;
	}
	case VAR_STACK:
		lua_pushvalue(cL, v->index);
		return lua_type(cL, -1);
	}
	return LUA_TNONE;
}

// extract L top into cL, return the lua type or LUA_TNONE(failed)
static int
eval_value(rlua_State *L, lua_State *cL) {
	if (lua_checkstack(cL, 1) == 0)
		return rluaL_error(L, "stack overflow");
	int t = copy_fromX(L, cL);
	if (t != LUA_TNONE) {
		return t;
	}
	t = rlua_type(L, -1);
	if (t == LUA_TUSERDATA) {
		struct value *v = (struct value *)rlua_touserdata(L, -1);
		rlua_getuservalue(L, -1);
		t = eval_value_(L, cL, v);
		rlua_pop(L, 1);	// pop uservalue
		return t;
	}
	return LUA_TNONE;
}

// assign cL top into ref object in L. pop cL.
// return 0 failed
static int
assign_value(rlua_State *L, struct value * v, lua_State *cL) {
	int top = lua_gettop(cL);
	switch (v->type) {
	case VAR_FRAME_LOCAL: {
		lua_Debug ar;
		if (lua_getstack(cL, v->frame, &ar) == 0) {
			break;
		}
		if (lua_setlocal(cL, &ar, v->index) != NULL) {
			return 1;
		}
		break;
	}
	case VAR_GLOBAL:
	case VAR_REGISTRY:
	case VAR_FRAME_FUNC:
	case VAR_STACK:
		// Can't assign frame func, etc.
		break;
	case VAR_INDEX:
	case VAR_INDEX_OBJ: {
		int t = eval_value_(L, cL, v+1);
		if (t == LUA_TNONE)
			break;
		if (t != LUA_TTABLE) {
			// only table can be index
			break;
		}
		if (v->type == VAR_INDEX) {
			if (v->index == 0) {
				rlua_pushnil(L);
			} else {
				rlua_rawgeti(L, -1, v->index);
			}
			if (copy_fromX(L, cL) == LUA_TNONE) {
				break;
			}
		} else {
			if (eval_value_(L, cL, v+1+v->index) == LUA_TNONE) {
				break;
			}
		}
		// in cL : key, table, value, ...
		if (v->frame == 0) {
			// index key
			lua_pushvalue(cL, -3);	// value, key, table, value, ...
			lua_rawset(cL, -3);	// table, value, ...
			lua_pop(cL, 2);
			return 1;
		} else {
			// next key can't assign
			break;
		}
	}
	case VAR_INDEX_KEY:
		break;
	case VAR_INDEX_VAL: {
		int t = eval_value_(L, cL, v+1);
		if (t == LUA_TNONE)
			break;
		if (t != LUA_TTABLE) {
			break;
		}
		lua_insert(cL, -2);
		if (!remotedebug::table::set_v(cL, -2, v->index)) {
			break;
		}
		lua_pop(cL, 1);
		return 1;
	}
	case VAR_UPVALUE: {
		int t = eval_value_(L, cL, v+1);
		if (t == LUA_TNONE)
			break;
		if (t != LUA_TFUNCTION) {
			// only function has upvalue
			break;
		}
		// swap function and value
		lua_insert(cL, -2);
		if (lua_setupvalue(cL, -2, v->index) != NULL) {
			lua_pop(cL, 1);
			return 1;
		}
		break;
	}
	case VAR_METATABLE: {
		if (v->frame == 1) {
			switch(v->index) {
			case LUA_TNIL:
				lua_pushnil(cL);
				break;
			case LUA_TBOOLEAN:
				lua_pushboolean(cL, 0);
				break;
			case LUA_TNUMBER:
				lua_pushinteger(cL, 0);
				break;
			case LUA_TSTRING:
				lua_pushstring(cL, "");
				break;
			case LUA_TLIGHTUSERDATA:
				lua_pushlightuserdata(cL, NULL);
				break;
			default:
				// Invalid
				return 0;
			}
		} else {
			int t = eval_value_(L, cL, v+1);
			if (t != LUA_TTABLE && t != LUA_TUSERDATA) {
				break;
			}
		}
		lua_insert(cL, -2);
		int metattype = lua_type(cL, -1);
		if (metattype != LUA_TNIL && metattype != LUA_TTABLE) {
			break;
		}
		lua_setmetatable(cL, -2);
		lua_pop(cL, 1);
		return 1;
	}
	case VAR_USERVALUE: {
		int t = eval_value_(L, cL, v+1);
		if (t != LUA_TUSERDATA) {
			break;
		}
		lua_insert(cL, -2);
		lua_setuservalue(cL, -2);
		lua_pop(cL, 1);
		return 1;
	}
	}
	lua_settop(cL, top-1);
	return 0;
}


static void
get_value(rlua_State *L, lua_State *cL) {
	if (eval_value(L, cL) == LUA_TNONE) {
		rlua_pop(L, 1);
		rlua_pushnil(L);
		// failed
		return;
	}
	rlua_pop(L, 1);
	copyvalue(cL, L);
	lua_pop(cL,1);
}

static int
safetostring(lua_State *L) {
	luaL_tolstring(L, 1, 0);
	return 1;
}

static void
tostring(rlua_State *L, lua_State *cL) {
	if (eval_value(L, cL) == LUA_TNONE) {
		rlua_pop(L, 1);
		rlua_pushstring(L, "nil");
		// failed
		return;
	}
	rlua_pop(L, 1);
	lua_pushcfunction(cL, safetostring);
	lua_insert(cL, -2);
	lua_pcall(cL, 1, 1, 0);
	copyvalue(cL, L);
	lua_pop(cL,1);
}

static const char *
get_frame_local(rlua_State *L, lua_State *cL, int frame, int index, int getref) {
	lua_Debug ar;
	if (lua_getstack(cL, frame, &ar) == 0) {
		return NULL;
	}
	if (lua_checkstack(cL, 1) == 0) {
		rluaL_error(L, "stack overflow");
	}
	const char * name = lua_getlocal(cL, &ar, index);
	if (name == NULL)
		return NULL;
	if (!getref && copy_toX(cL, L) != LUA_TNONE) {
		lua_pop(cL, 1);
		return name;
	}
	lua_pop(cL, 1);
	struct value *v = (struct value *)rlua_newuserdata(L, sizeof(struct value));
	v->type = VAR_FRAME_LOCAL;
	v->frame = frame;
	v->index = index;
	return name;
}

static int
get_frame_func(rlua_State *L, lua_State *cL, int frame) {
	lua_Debug ar;
	if (lua_getstack(cL, frame, &ar) == 0) {
		return 0;
	}
	if (lua_checkstack(cL, 1) == 0) {
		rluaL_error(L, "stack overflow");
	}
	if (lua_getinfo(cL, "f", &ar) == 0) {
		return 0;
	}
	lua_pop(cL, 1);

	struct value *v = (struct value *)rlua_newuserdata(L, sizeof(struct value));
	v->type = VAR_FRAME_FUNC;
	v->frame = frame;
	v->index = 0;
	return 1;
}

static int
get_stack(rlua_State *L, lua_State *cL, int index, int getref) {
	if (index > lua_gettop(cL)) {
		return 0;
	}
	if (lua_checkstack(cL, 1) == 0) {
		rluaL_error(L, "stack overflow");
	}
	if (!getref) {
		lua_pushvalue(cL, index);
		if (copy_toX(cL, L) != LUA_TNONE) {
			lua_pop(cL, 1);
			return 1;
		}
		lua_pop(cL, 1);
	}
	struct value *v = (struct value *)rlua_newuserdata(L, sizeof(struct value));
	v->type = VAR_STACK;
	v->index = index;
	return 1;
}

static void
copy_table(rlua_State *L, int index) {
	if (rlua_getuservalue(L, index) == LUA_TTABLE) {
		int n = (int)rlua_rawlen(L, -1);
		rlua_createtable(L, n, 0);
		// v, ut, []
		int i;
		for (i=1;i<=n;i++) {
			rlua_rawgeti(L, -2, i);
			rlua_rawseti(L, -2, i);
		}
		rlua_setuservalue(L, -3);
	}
	rlua_pop(L, 1);
}

// table key
static void
new_index(rlua_State *L, int type) {
	struct value *t = (struct value *)rlua_touserdata(L, -2);
	int sz = sizeof_value(t);
	struct value *v = (struct value *)rlua_newuserdata(L, sizeof(struct value) * (sz + 1));
	v->type = VAR_INDEX;
	v->frame = type;
	memcpy(v+1,t,sz * sizeof(struct value));
	// t k v
	copy_table(L, -3);	// copy uservalue from t to v
	if (rlua_type(L, -2) == LUA_TNIL) {
		// key is nil
		v->index = 0;
	} else {
		if (rlua_getuservalue(L, -3) != LUA_TTABLE) {
			rlua_pop(L, 1);
			rlua_createtable(L, 1, 0);
		}
		// t k v []
		int n = (int)rlua_rawlen(L, -1);
		rlua_pushvalue(L, -3);
		// t k v [] k
		rlua_rawseti(L, -2, n+1);
		// t k v [... k]
		rlua_setuservalue(L, -2);
		v->index = n+1;
	}
}

static int
append_table(rlua_State *L, int index) {
	if (rlua_getuservalue(L, index) != LUA_TTABLE) {
		rlua_pop(L, 1);
		return 0;
	}
	// ..., v , [uv]
	if (rlua_getuservalue(L, -2) != LUA_TTABLE) {
		rlua_pop(L, 2);
		// ..., v
		copy_table(L, index);
		return 0;
	}
	// ..., v, [from_uv], [to_uv]
	int offset = (int)rlua_rawlen(L, -1);
	int i;
	for (i=1;;i++) {
		if (rlua_rawgeti(L, -2, i) == LUA_TNIL) {
			// ..., v, [], [] , nil
			break;
		}
		rlua_rawseti(L, -2, i + offset);
	}
	rlua_pop(L, 3);
	return offset;
}

// table key
static void
new_index_object(rlua_State *L, int type) {
	struct value *t = (struct value *)rlua_touserdata(L, -2);
	int ts = sizeof_value(t);
	struct value *k = (struct value *)rlua_touserdata(L, -1);
	int ks = sizeof_value(k);

	struct value *v = (struct value *)rlua_newuserdata(L, sizeof(struct value) * (ts + ks + 1));
	v->type = VAR_INDEX_OBJ;
	v->frame = type;
	v->index = ts;
	memcpy(v+1,t,ts * sizeof(struct value));
	// t k v
	copy_table(L, -3);	// copy uservalue from t to v
	memcpy(v+1+ts,k,ks * sizeof(struct value));
	int offset = append_table(L, -2);	// move uservalue from k to v
	if (offset) {
		int i;
		v = v+1+ts;
		for (i=0;i<ks;i++,v++) {
			if (v->type == VAR_INDEX && v->index != 0) {
				v->index += offset;
			}
		}
	}
}

static void
create_index(rlua_State *L, int type) {
	if (rlua_type(L, -1) == LUA_TUSERDATA) {
		new_index_object(L, type);
	}
	else {
		new_index(L, type);
	}
}

// table key
static int
table_key(rlua_State *L, lua_State *cL) {
	if (lua_checkstack(cL, 3) == 0) {
		return rluaL_error(L, "stack overflow");
	}
	rlua_insert(L, -2);	// L : key table
	int t = eval_value(L, cL);
	if (t != LUA_TTABLE) {
		lua_pop(cL, 1);	// pop table
		rlua_pop(L, 2);	// pop k/t
		return 0;
	}
	rlua_insert(L, -2);	// L : table key
	if (eval_value(L, cL) == LUA_TNONE) {	// key
		lua_pop(cL, 1);	// pop table
		rlua_pop(L, 2);	// pop k/t
		return 0;
	}
	return 1;
}

// input cL : table key [value]
// input L :  table key
// output cL :
// output L : v(key or value)
static void
combine_tk(rlua_State *L, lua_State *cL, int type, int getref) {
	if (!getref && copy_toX(cL, L) != LUA_TNONE) {
		lua_pop(cL, 2);
		// L : t, k, v
		rlua_replace(L, -3);
		rlua_pop(L, 1);
		return;
	}
	lua_pop(cL, 2);	// pop t v from cL
	// L : t, k
	create_index(L, type);
	// L : t, k, v
	rlua_replace(L, -3);
	rlua_pop(L, 1);
}

static int
get_index(rlua_State *L, lua_State *cL, int getref) {
	if (table_key(L, cL) == 0)
		return 0;
	lua_rawget(cL, -2);	// cL : table value
	combine_tk(L, cL, VARKEY_INDEX, getref);
	return 1;
}

// table last_key
static int
next_key(rlua_State *L, lua_State *cL, int getref) {
	if (table_key(L, cL) == 0)
		return 0;
	if (lua_next(cL, -2) == 0) {
		lua_pop(cL, 1);	// remove table
		return 0;
	}
	lua_pop(cL, 1);	// remove value
	combine_tk(L, cL, VARKEY_NEXT, getref);
	return 1;
}

static const char *
get_upvalue(rlua_State *L, lua_State *cL, int index, int getref) {
	if (rlua_type(L, -1) != LUA_TUSERDATA) {
		rlua_pop(L, 1);
		return NULL;
	}
	int t = eval_value(L, cL);
	if (t == LUA_TNONE) {
		rlua_pop(L, 1);	// remove function object
		return NULL;
	}
	if (t != LUA_TFUNCTION) {
		rlua_pop(L, 1);	// remove function object
		lua_pop(cL, 1);	// remove none function
		return NULL;
	}
	const char *name = lua_getupvalue(cL, -1, index);
	if (name == NULL) {
		rlua_pop(L, 1);	// remove function object
		lua_pop(cL, 1);	// remove function
		return NULL;
	}

	if (!getref && copy_toX(cL, L) != LUA_TNONE) {
		rlua_replace(L, -2);	// remove function object
		lua_pop(cL, 1);
		return name;
	}
	lua_pop(cL, 2);	// remove func / upvalue
	struct value *f = (struct value *)rlua_touserdata(L, -1);
	int sz = sizeof_value(f);
	struct value *v = (struct value *)rlua_newuserdata(L, sizeof(struct value) * (1+sz));
	v->type = VAR_UPVALUE;
	v->frame = 0;
	v->index = index;
	memcpy(v+1, f, sizeof(struct value) * sz);
	copy_table(L, -2);
	rlua_replace(L, -2);	// remove function object
	return name;
}

static struct value *
get_registry(rlua_State *L, int type) {
	switch (type) {
	case VAR_GLOBAL:
	case VAR_REGISTRY:
		break;
	default:
		return NULL;
	}
	struct value * v = (struct value *)rlua_newuserdata(L, sizeof(struct value));
	v->frame = 0;
	v->index = 0;
	v->type = type;
	return v;
}

static struct value *
get_metatable(rlua_State *L, lua_State *cL, int getref) {
	if (lua_checkstack(cL, 2)==0)
		rluaL_error(L, "stack overflow");
	int t = eval_value(L, cL);
	if (t == LUA_TNONE) {
		rlua_pop(L, 1);
		return NULL;
	}
	if (!getref) {
		if (lua_getmetatable(cL,-1) == 0) {
			rlua_pop(L, 1);
			lua_pop(cL, 1);
			return NULL;
		}
		lua_pop(cL, 2);
	} else {
		lua_pop(cL, 1);
	}
	if (t == LUA_TTABLE || t == LUA_TUSERDATA) {
		struct value *t = (struct value *)rlua_touserdata(L, -1);
		int sz = sizeof_value(t);
		struct value *v = (struct value *)rlua_newuserdata(L, sizeof(struct value) * (sz + 1));
		v->type = VAR_METATABLE;
		v->frame = 0;
		v->index = 0;
		memcpy(v+1,t,sz * sizeof(struct value));
		// t v
		copy_table(L, -2);
		rlua_replace(L, -2);
		return v;
	} else {
		rlua_pop(L, 1);
		struct value *v = (struct value *)rlua_newuserdata(L, sizeof(struct value));
		v->type = VAR_METATABLE;
		v->frame = 1;
		v->index = t;
		return v;
	}
}

static int
get_uservalue(rlua_State *L, lua_State *cL, int index, int getref) {
	if (lua_checkstack(cL, 2)==0)
		return rluaL_error(L, "stack overflow");
	int t = eval_value(L, cL);
	if (t == LUA_TNONE) {
		rlua_pop(L, 1);
		return 0;
	}

	if (t != LUA_TUSERDATA) {
		lua_pop(cL, 1);
		rlua_pop(L, 1);
		return 0;
	}

	if (!getref) {
#if LUA_VERSION_NUM >= 504
		if (lua_getiuservalue(cL, -1, index) == LUA_TNONE) {
			lua_pop(cL, 1);
			rlua_pop(L, 1);
			return 0;
		}
#else
		if (index > 1) {
			rlua_pop(L, 1);
			return 0;
		}
		lua_getuservalue(cL, -1);
#endif
		if (copy_toX(cL, L) != LUA_TNONE) {
			lua_pop(cL, 2);	// pop userdata / uservalue
			rlua_replace(L, -2);
			return 1;
		}
	}

	// pop full userdata
	lua_pop(cL, 1);

	// L : value
	// cL : value uservalue
	struct value *u = (struct value *)rlua_touserdata(L, -1);
	int sz = sizeof_value(u);
	struct value *v = (struct value *)rlua_newuserdata(L, sizeof(struct value) * (sz + 1));
	v->type = VAR_USERVALUE;
	v->frame = 0;
	v->index = index;
	memcpy(v+1,u,sz * sizeof(struct value));
	// u v
	copy_table(L, -2);
	rlua_replace(L, -2);
	return 1;
}

static void
combine_kv(rlua_State *L, lua_State *cL, int getref, int type, int index) {
	if (!getref && copy_toX(cL, L) != LUA_TNONE) {
		rlua_replace(L, -2);
		lua_pop(cL, 1);
		return;
	}
	lua_pop(cL, 1);
	struct value *f = (struct value *)rlua_touserdata(L, -1);
	int sz = sizeof_value(f);
	struct value *v = (struct value *)rlua_newuserdata(L, sizeof(struct value) * (1+sz));
	v->type = type;
	v->frame = 0;
	v->index = index;
	memcpy(v+1, f, sizeof(struct value) * sz);
	copy_table(L, -2);
	rlua_replace(L, -2);
}
