#include <lua.hpp>
#include "lua_compat.h"
#include "rlua.h"
#include "rdebug_table.h"
#include <stdint.h>
#include <string.h>
#include <stdio.h>
#include <limits>
#include "rdebug_table.h"

int debug_pcall(lua_State* L, int nargs, int nresults, int errfunc);

lua_State* get_host(rlua_State *L);

enum class VAR : uint8_t {
	FRAME_LOCAL,	// stack(frame, index)
	FRAME_FUNC,		// stack(frame).func
	UPVALUE,		// func[index]
	GLOBAL,			// _G
	REGISTRY,		// REGISTRY
	METATABLE,		// table.metatable
	USERVALUE,		// userdata.uservalue
	STACK,
	INDEX_KEY,
	INDEX_VAL,
	INDEX_INT,
	INDEX_STR,
};


struct value {
	VAR type;
	union {
		struct {
			uint16_t frame;
			int16_t  n;
		} local;
		int index;
	};
};

// return record number of value 
static int
sizeof_value(struct value *v) {
	switch (v->type) {
	case VAR::FRAME_LOCAL:
	case VAR::FRAME_FUNC:
	case VAR::GLOBAL:
	case VAR::REGISTRY:
	case VAR::STACK:
		return sizeof(struct value);
	case VAR::INDEX_STR:
		return sizeof_value((struct value *)((const char*)(v+1) + v->index)) + sizeof(struct value) + v->index;
	case VAR::METATABLE:
		if (v->index != LUA_TTABLE && v->index != LUA_TUSERDATA) {
			return sizeof(struct value);
		}
		// go through
	case VAR::UPVALUE:
	case VAR::USERVALUE:
	case VAR::INDEX_KEY:
	case VAR::INDEX_VAL:
	case VAR::INDEX_INT:
		return sizeof_value(v+1) + sizeof(struct value);
	}
	return 0;
}

static struct value *
create_value(rlua_State *L, VAR type) {
	struct value *v = (struct value *)rlua_newuserdata(L, sizeof(struct value));
	v->type = type;
	return v;
}

static struct value *
create_value(rlua_State *L, VAR type, int t, size_t extrasz = 0) {
	struct value *f = (struct value *)rlua_touserdata(L, t);
	int sz = sizeof_value(f);
	struct value *v = (struct value *)rlua_newuserdata(L, sz + sizeof(struct value) + extrasz);
	v->type = type;
	memcpy((char*)(v+1)+extrasz,f,sz);
	return v;
}

// copy a value from -> to, return the lua type of copied or LUA_TNONE
static int
copy_toR(lua_State *from, rlua_State *to) {
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

void
copyvalue(lua_State *from, rlua_State *to) {
	if (copy_toR(from, to) == LUA_TNONE) {
		rlua_pushfstring(to, "%s: %p",
			lua_typename(from, lua_type(from, -1)),
			lua_topointer(from, -1)
		);
	}
}

// L top : value, uservalue
static int
eval_value_(lua_State *cL, struct value *v) {
	switch (v->type) {
	case VAR::FRAME_LOCAL: {
		lua_Debug ar;
		if (lua_getstack(cL, v->local.frame, &ar) == 0)
			break;
		const char* name = lua_getlocal(cL, &ar, v->local.n);
		if (name) {
			return lua_type(cL, -1);
		}
		break;
	}
	case VAR::FRAME_FUNC: {
		lua_Debug ar;
		if (lua_getstack(cL, v->index, &ar) == 0)
			break;
		if (lua_getinfo(cL, "f", &ar) == 0)
			break;
		return LUA_TFUNCTION;
	}
	case VAR::INDEX_INT:{
		int t = eval_value_(cL, v+1);
		if (t == LUA_TNONE)
			break;
		if (t != LUA_TTABLE) {
			// only table can be index
			lua_pop(cL, 1);
			break;
		}
		lua_pushinteger(cL, (lua_Integer)v->index);
		lua_rawget(cL, -2);
		lua_replace(cL, -2);
		return lua_type(cL, -1);
	}
	case VAR::INDEX_STR:{
		int t = eval_value_(cL, (struct value *)((const char*)(v+1) + v->index));
		if (t == LUA_TNONE)
			break;
		if (t != LUA_TTABLE) {
			// only table can be index
			lua_pop(cL, 1);
			break;
		}
		lua_pushlstring(cL, (const char*)(v+1), (size_t)v->index);
		lua_rawget(cL, -2);
		lua_replace(cL, -2);
		return lua_type(cL, -1);
	}
	case VAR::INDEX_KEY:
	case VAR::INDEX_VAL: {
		int t = eval_value_(cL, v+1);
		if (t == LUA_TNONE)
			break;
		if (t != LUA_TTABLE) {
			// only table can be index
			lua_pop(cL, 1);
			break;
		}
		bool ok = v->type == VAR::INDEX_KEY
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
	case VAR::UPVALUE: {
		int t = eval_value_(cL, v+1);
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
			lua_pop(cL, 1);
			break;
		}
	}
	case VAR::GLOBAL:
#if LUA_VERSION_NUM == 501
		lua_pushvalue(cL, LUA_GLOBALSINDEX);
		return LUA_TTABLE;
#else
		return lua::rawgeti(cL, LUA_REGISTRYINDEX, LUA_RIDX_GLOBALS);
#endif
	case VAR::REGISTRY:
		lua_pushvalue(cL, LUA_REGISTRYINDEX);
		return LUA_TTABLE;
	case VAR::METATABLE:
		if (v->index != LUA_TTABLE && v->index != LUA_TUSERDATA) {
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
			int t = eval_value_(cL, v+1);
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
	case VAR::USERVALUE: {
		int t = eval_value_(cL, v+1);
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
	case VAR::STACK:
		lua_pushvalue(cL, v->index);
		return lua_type(cL, -1);
	}
	return LUA_TNONE;
}

static int
copy_fromR(rlua_State *from, lua_State *to) {
	if (lua_checkstack(to, 1) == 0) {
		return rluaL_error(from, "stack overflow");
	}
	int t = rlua_type(from, -1);
	switch (t) {
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
	case LUA_TUSERDATA: {
		if (lua_checkstack(to, 3) == 0) {
			return rluaL_error(from, "stack overflow");
		}
		struct value *v = (struct value *)rlua_touserdata(from, -1);
		return eval_value_(to, v);
	}
	default:
		return LUA_TNONE;
	}
	return t;
}

// assign cL top into ref object in L. pop cL.
// return 0 failed
static int
assign_value(struct value * v, lua_State *cL) {
	int top = lua_gettop(cL);
	switch (v->type) {
	case VAR::FRAME_LOCAL: {
		lua_Debug ar;
		if (lua_getstack(cL, v->local.frame, &ar) == 0) {
			break;
		}
		if (lua_setlocal(cL, &ar, v->local.n) != NULL) {
			return 1;
		}
		break;
	}
	case VAR::GLOBAL:
	case VAR::REGISTRY:
	case VAR::FRAME_FUNC:
	case VAR::STACK:
		// Can't assign frame func, etc.
		break;
	case VAR::INDEX_INT: {
		int t = eval_value_(cL, v+1);
		if (t == LUA_TNONE)
			break;
		if (t != LUA_TTABLE) {
			// only table can be index
			break;
		}
		lua_pushinteger(cL, (lua_Integer)v->index);	// key, table, value, ...
		lua_pushvalue(cL, -3);	// value, key, table, value, ...
		lua_rawset(cL, -3);	// table, value, ...
		lua_pop(cL, 2);
		return 1;
	}
	case VAR::INDEX_STR: {
		int t = eval_value_(cL, (struct value *)((const char*)(v+1) + v->index));
		if (t == LUA_TNONE)
			break;
		if (t != LUA_TTABLE) {
			// only table can be index
			break;
		}
		lua_pushlstring(cL, (const char*)(v+1), (size_t)v->index); // key, table, value, ...
		lua_pushvalue(cL, -3);	// value, key, table, value, ...
		lua_rawset(cL, -3);	// table, value, ...
		lua_pop(cL, 2);
		return 1;
	}
	case VAR::INDEX_KEY:
		break;
	case VAR::INDEX_VAL: {
		int t = eval_value_(cL, v+1);
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
	case VAR::UPVALUE: {
		int t = eval_value_(cL, v+1);
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
	case VAR::METATABLE: {
		if (v->index != LUA_TTABLE && v->index != LUA_TUSERDATA) {
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
			int t = eval_value_(cL, v+1);
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
	case VAR::USERVALUE: {
		int t = eval_value_(cL, v+1);
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

static const char *
get_frame_local(rlua_State *L, lua_State *cL, uint16_t frame, int16_t n, int getref) {
	lua_Debug ar;
	if (lua_getstack(cL, frame, &ar) == 0) {
		return NULL;
	}
	if (lua_checkstack(cL, 1) == 0) {
		rluaL_error(L, "stack overflow");
	}
	const char * name = lua_getlocal(cL, &ar, n);
	if (name == NULL)
		return NULL;
	if (!getref && copy_toR(cL, L) != LUA_TNONE) {
		lua_pop(cL, 1);
		return name;
	}
	lua_pop(cL, 1);
	struct value *v = create_value(L, VAR::FRAME_LOCAL);
	v->local.frame = frame;
	v->local.n = n;
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

	struct value *v = create_value(L, VAR::FRAME_FUNC);
	v->index = frame;
	return 1;
}

static int
get_stack(rlua_State *L, lua_State *cL, int index) {
	if (index > lua_gettop(cL)) {
		return 0;
	}
	if (lua_checkstack(cL, 1) == 0) {
		rluaL_error(L, "stack overflow");
	}
	lua_pushvalue(cL, index);
	if (copy_toR(cL, L) != LUA_TNONE) {
		lua_pop(cL, 1);
		return 1;
	}
	lua_pop(cL, 1);
	struct value *v = create_value(L, VAR::STACK);
	v->index = index;
	return 1;
}

// table key
static int
table_key(rlua_State *L, lua_State *cL) {
	if (lua_checkstack(cL, 3) == 0) {
		return rluaL_error(L, "stack overflow");
	}
	rlua_insert(L, -2);	// L : key table
	if (copy_fromR(L, cL) != LUA_TTABLE) {
		lua_pop(cL, 1);	// pop table
		rlua_pop(L, 2);	// pop k/t
		return 0;
	}
	rlua_insert(L, -2);	// L : table key
	if (copy_fromR(L, cL) == LUA_TNONE) {	// key
		lua_pop(cL, 1);	// pop table
		rlua_pop(L, 2);	// pop k/t
		return 0;
	}
	return 1;
}

// table key
static void
new_index(rlua_State *L) {
	struct value *v = create_value(L, VAR::INDEX_INT, -2);
	v->type = VAR::INDEX_INT;
	v->index = (int)rlua_tointeger(L, -2);
}

// input cL : table key [value]
// input L :  table key
// output cL :
// output L : v(key or value)
static void
combine_index(rlua_State *L, lua_State *cL, int getref) {
	if (!getref && copy_toR(cL, L) != LUA_TNONE) {
		lua_pop(cL, 2);
		// L : t, k, v
		rlua_replace(L, -3);
		rlua_pop(L, 1);
		return;
	}
	lua_pop(cL, 2);	// pop t v from cL
	// L : t, k
	new_index(L);
	// L : t, k, v
	rlua_replace(L, -3);
	rlua_pop(L, 1);
}

static int
get_index(rlua_State *L, lua_State *cL, int getref) {
	if (table_key(L, cL) == 0)
		return 0;
	lua_rawget(cL, -2);	// cL : table value
	combine_index(L, cL, getref);
	return 1;
}

// table key
static void
new_field(rlua_State *L) {
	size_t len = 0;
	const char* str = rlua_tolstring(L, -1, &len);
	struct value *v = create_value(L, VAR::INDEX_STR, -2, len);
	v->index = (int)len;
	memcpy(v+1,str,len);
}

// input cL : table key [value]
// input L :  table key
// output cL :
// output L : v(key or value)
static void
combine_field(rlua_State *L, lua_State *cL, int getref) {
	if (!getref && copy_toR(cL, L) != LUA_TNONE) {
		lua_pop(cL, 2);
		// L : t, k, v
		rlua_replace(L, -3);
		rlua_pop(L, 1);
		return;
	}
	lua_pop(cL, 2);	// pop t v from cL
	// L : t, k
	new_field(L);
	// L : t, k, v
	rlua_replace(L, -3);
	rlua_pop(L, 1);
}

static int
get_field(rlua_State *L, lua_State *cL, int getref) {
	if (table_key(L, cL) == 0)
		return 0;
	lua_rawget(cL, -2);	// cL : table value
	combine_field(L, cL, getref);
	return 1;
}

static const char *
get_upvalue(rlua_State *L, lua_State *cL, int index, int getref) {
	if (rlua_type(L, -1) != LUA_TUSERDATA) {
		rlua_pop(L, 1);
		return NULL;
	}
	int t = copy_fromR(L, cL);
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

	if (!getref && copy_toR(cL, L) != LUA_TNONE) {
		rlua_replace(L, -2);	// remove function object
		lua_pop(cL, 1);
		return name;
	}
	lua_pop(cL, 2);	// remove func / upvalue
	struct value *v = create_value(L, VAR::UPVALUE, -1);
	v->index = index;
	rlua_replace(L, -2);	// remove function object
	return name;
}

static int
get_registry(rlua_State *L, VAR type) {
	switch (type) {
	case VAR::GLOBAL:
	case VAR::REGISTRY:
		break;
	default:
		return 0;
	}
	struct value *v = create_value(L, type);
	v->index = 0;
	return 1;
}

static int
get_metatable(rlua_State *L, lua_State *cL, int getref) {
	if (lua_checkstack(cL, 2)==0)
		rluaL_error(L, "stack overflow");
	int t = copy_fromR(L, cL);
	if (t == LUA_TNONE) {
		rlua_pop(L, 1);
		return 0;
	}
	if (!getref) {
		if (lua_getmetatable(cL,-1) == 0) {
			rlua_pop(L, 1);
			lua_pop(cL, 1);
			return 0;
		}
		lua_pop(cL, 2);
	} else {
		lua_pop(cL, 1);
	}
	if (t == LUA_TTABLE || t == LUA_TUSERDATA) {
		struct value *v = create_value(L, VAR::METATABLE, -1);
		v->type = VAR::METATABLE;
		v->index = t;
		rlua_replace(L, -2);
		return 1;
	} else {
		rlua_pop(L, 1);
		struct value *v = create_value(L, VAR::METATABLE);
		v->index = t;
		return 1;
	}
}

static int
get_uservalue(rlua_State *L, lua_State *cL, int index, int getref) {
	if (lua_checkstack(cL, 2)==0)
		return rluaL_error(L, "stack overflow");
	int t = copy_fromR(L, cL);
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
		if (copy_toR(cL, L) != LUA_TNONE) {
			lua_pop(cL, 2);	// pop userdata / uservalue
			rlua_replace(L, -2);
			return 1;
		}
	}

	// pop full userdata
	lua_pop(cL, 1);

	// L : value
	// cL : value uservalue
	struct value *v = create_value(L, VAR::USERVALUE, -1);
	v->index = index;
	rlua_replace(L, -2);
	return 1;
}

static void
combine_key(rlua_State *L, lua_State *cL, int t, int index) {
	if (copy_toR(cL, L) != LUA_TNONE) {
		lua_pop(cL, 1);
		return;
	}
	lua_pop(cL, 1);
	struct value *v = create_value(L, VAR::INDEX_KEY, t);
	v->index = index;
}

static void
combine_val(rlua_State *L, lua_State *cL, int t, int index, int ref) {
	if (ref) {
		struct value *v = create_value(L, VAR::INDEX_VAL, t);
		v->index = index;
		if (copy_toR(cL, L) == LUA_TNONE) {
			rlua_pushvalue(L, -1);
		}
		lua_pop(cL, 1);
		return;
	}
	if (copy_toR(cL, L) == LUA_TNONE) {
		struct value *v = create_value(L, VAR::INDEX_VAL, t);
		v->index = index;
	}
	lua_pop(cL, 1);
}

// frame, index
// return value, name
static int
client_getlocal(rlua_State *L, int getref) {
	rlua_Integer frame = rluaL_checkinteger(L, 1);
	rlua_Integer index = rluaL_checkinteger(L, 2);
	if (frame < 0 || frame > (std::numeric_limits<uint16_t>::max)()) {
		return rluaL_error(L, "frame must be `uint16_t`");
	}
	if (index == 0 || index > (std::numeric_limits<uint8_t>::max)() || -index > (std::numeric_limits<uint8_t>::max)()) {
		return rluaL_error(L, "index must be `uint8_t`");
	}
	lua_State *cL = get_host(L);
	const char *name = get_frame_local(L, cL, (uint16_t)frame, (int16_t)index, getref);
	if (name) {
		rlua_pushstring(L, name);
		rlua_insert(L, -2);
		return 2;
	}

	return 0;
}

static int
lclient_getlocal(rlua_State *L) {
	return client_getlocal(L, 1);
}

static int
lclient_getlocalv(rlua_State *L) {
	return client_getlocal(L, 0);
}

// frame
// return func
static int
lclient_getfunc(rlua_State *L) {
	int frame = (int)rluaL_checkinteger(L, 1);

	lua_State *cL = get_host(L);

	if (get_frame_func(L, cL, frame)) {
		return 1;
	}

	return 0;
}

static int
client_index(rlua_State *L, int getref) {
	lua_State *cL = get_host(L);
	if (rlua_gettop(L) != 2) {
		return rluaL_error(L, "need table key");
	}
	rlua_Integer i = rluaL_checkinteger(L, 2);
	if (i <= 0 || i > (std::numeric_limits<int>::max)()) {
		return rluaL_error(L, "must be `unsigned int`");
	}
	if (get_index(L, cL, getref)) {
		return 1;
	}
	return 0;
}

static int
lclient_index(rlua_State *L) {
	return client_index(L, 1);
}

static int
lclient_indexv(rlua_State *L) {
	return client_index(L, 0);
}

static int
client_field(rlua_State *L, int getref) {
	lua_State *cL = get_host(L);
	if (rlua_gettop(L) != 2) {
		return rluaL_error(L, "need table key");
	}
	rluaL_checktype(L, 2, LUA_TSTRING);
	if (get_field(L, cL, getref)) {
		return 1;
	}
	return 0;
}

static int
lclient_field(rlua_State *L) {
	return client_field(L, 1);
}

static int
lclient_fieldv(rlua_State *L) {
	return client_field(L, 0);
}

static int
lclient_getstack(rlua_State *L) {
	lua_State *cL = get_host(L);
	if (rlua_gettop(L) == 0) {
		rlua_pushinteger(L, lua_gettop(cL));
		return 1;
	}
	int index = (int)rluaL_checkinteger(L, 1);
	if (get_stack(L, cL, index)) {
		return 1;
	}
	return 0;
}

static int
tablehash(rlua_State *L, int ref) {
	lua_State *cL = get_host(L);
	rlua_Integer maxn = rluaL_optinteger(L, 2, std::numeric_limits<unsigned int>::max());
	rlua_settop(L, 1);
	if (lua_checkstack(cL, 4) == 0) {
		return rluaL_error(L, "stack overflow");
	}
	if (copy_fromR(L, cL) != LUA_TTABLE) {
		lua_pop(cL, 1);
		return 0;
	}
	const void* t = lua_topointer(cL, -1);
	if (!t) {
		lua_pop(cL, 1);
		return 0;
	}
	rlua_newtable(L);
	rlua_Integer n = 0;
	unsigned int hsize = remotedebug::table::hash_size(t);
	for (unsigned int i = 0; i < hsize; ++i) {
		if (remotedebug::table::get_kv(cL, t, i)) {
			if (--maxn < 0) {
				lua_pop(cL, 3);
				return 1;
			}
			combine_key(L, cL, 1, i);
			rlua_rawseti(L, -2, ++n);
			combine_val(L, cL, 1, i, ref);
			if (ref) {
				rlua_rawseti(L, -3, ++n);
			}
			rlua_rawseti(L, -2, ++n);
		}
	}
	lua_pop(cL, 1);
	return 1;
}

static int
lclient_tablehash(rlua_State *L) {
	return tablehash(L, 1);
}

static int
lclient_tablehashv(rlua_State *L) {
	return tablehash(L, 0);
}

static int
lclient_tablesize(rlua_State *L) {
	lua_State* cL = get_host(L);
	if (copy_fromR(L, cL) != LUA_TTABLE) {
		lua_pop(cL, 1);
		return 0;
	}
	const void* t = lua_topointer(cL, -1);
	if (!t) {
		lua_pop(cL, 1);
		return 0;
	}
	rlua_pushinteger(L, remotedebug::table::array_size(t));
	rlua_pushinteger(L, remotedebug::table::hash_size(t));
	lua_pop(cL, 1);
	return 2;
}

static int
lclient_tablekey(rlua_State *L) {
	lua_State *cL = get_host(L);
	unsigned int idx = (unsigned int)rluaL_optinteger(L, 2, 0);
	rlua_settop(L, 1);
	if (lua_checkstack(cL, 2) == 0) {
		return rluaL_error(L, "stack overflow");
	}
	if (copy_fromR(L, cL) != LUA_TTABLE) {
		lua_pop(cL, 1);
		return 0;
	}
	const void* t = lua_topointer(cL, -1);
	if (!t) {
		lua_pop(cL, 1);
		return 0;
	}
	unsigned int hsize = remotedebug::table::hash_size(t);
	for (unsigned int i = idx; i < hsize; ++i) {
		if (remotedebug::table::get_k(cL, t, i)) {
			if (lua_type(cL, -1) == LUA_TSTRING) {
				size_t sz;
				const char *str = lua_tolstring(cL, -1, &sz);
				rlua_pushlstring(L, str, sz);
				rlua_pushinteger(L, i + 1);
				lua_pop(cL, 2);
				return 2;
			}
			lua_pop(cL, 1);
		}
	}
	lua_pop(cL, 1);
	return 0;
}

static int
lclient_value(rlua_State *L) {
	lua_State *cL = get_host(L);
	rlua_settop(L, 1);
	if (copy_fromR(L, cL) == LUA_TNONE) {
		rlua_pop(L, 1);
		rlua_pushnil(L);
		return 1;
	}
	rlua_pop(L, 1);
	copyvalue(cL, L);
	lua_pop(cL,1);
	return 1;
}

// userdata ref
// any value
// ref = value
static int
lclient_assign(rlua_State *L) {
	lua_State *cL = get_host(L);
	if (lua_checkstack(cL, 2) == 0)
		return rluaL_error(L, "stack overflow");
	rlua_settop(L, 2);
	if (copy_fromR(L, cL) == LUA_TNONE) {
		if (rlua_type(L, 2) != LUA_TUSERDATA) {
			return rluaL_error(L, "Invalid value type %s", rlua_typename(L, rlua_type(L, 2)));
		}
		lua_pushnil(cL);
	}
	if (lua_checkstack(cL, 3) == 0)
		return rluaL_error(L, "stack overflow");
	rluaL_checktype(L, 1, LUA_TUSERDATA);
	struct value * ref = (struct value *)rlua_touserdata(L, 1);
	int r = assign_value(ref, cL);
	rlua_pushboolean(L, r);
	return 1;
}

static int
lclient_type(rlua_State *L) {
	lua_State *cL = get_host(L);
	switch(rlua_type(L, 1)) {
	case LUA_TNIL:           rlua_pushstring(L, "nil");           return 1;
	case LUA_TBOOLEAN:       rlua_pushstring(L, "boolean");       return 1;
	case LUA_TSTRING:        rlua_pushstring(L, "string");        return 1;
	case LUA_TLIGHTUSERDATA: rlua_pushstring(L, "lightuserdata"); return 1;
	case LUA_TNUMBER:
#if LUA_VERSION_NUM >= 503
		if (rlua_isinteger(L, 1)) {
			rlua_pushstring(L, "integer");
		} else {
			rlua_pushstring(L, "float");
		}
#else
		rlua_pushstring(L, "float");
#endif
		return 1;
	case LUA_TUSERDATA:
		break;
	default:
		rluaL_error(L, "unexpected type: %s", rlua_typename(L, rlua_type(L, 1)));
		return 1;
	}
	if (lua_checkstack(cL, 3) == 0)
		return rluaL_error(L, "stack overflow");
	rlua_settop(L, 1);
	struct value *v = (struct value *)rlua_touserdata(L, 1);
	int t = eval_value_(cL, v);
	switch (t) {
	case LUA_TNONE:
		rlua_pushstring(L, "unknown");
		return 1;
	case LUA_TFUNCTION:
		if (lua_iscfunction(cL, -1)) {
			rlua_pushstring(L, "c function");
		} else {
			rlua_pushstring(L, "function");
		}
		break;
	case LUA_TNUMBER:
#if LUA_VERSION_NUM >= 503
		if (lua_isinteger(cL, -1)) {
			rlua_pushstring(L, "integer");
		} else {
			rlua_pushstring(L, "float");
		}
#else
		rlua_pushstring(L, "float");
#endif
		break;
	case LUA_TLIGHTUSERDATA:
		rlua_pushstring(L, "lightuserdata");
		break;
	default:
		rlua_pushstring(L, lua_typename(cL, t));
		break;
	}
	lua_pop(cL, 1);
	return 1;
}

static int
client_getupvalue(rlua_State *L, int getref) {
	int index = (int)rluaL_checkinteger(L, 2);
	rlua_settop(L, 1);
	lua_State *cL = get_host(L);

	const char *name = get_upvalue(L, cL, index, getref);
	if (name) {
		rlua_pushstring(L, name);
		rlua_insert(L, -2);
		return 2;
	}

	return 0;
}

static int
lclient_getupvalue(rlua_State *L) {
	return client_getupvalue(L, 1);
}

static int
lclient_getupvaluev(rlua_State *L) {
	return client_getupvalue(L, 0);
}

static int
client_getmetatable(rlua_State *L, int getref) {
	rlua_settop(L, 1);
	lua_State *cL = get_host(L);
	if (get_metatable(L, cL, getref)) {
		return 1;
	}
	return 0;
}

static int
lclient_getmetatable(rlua_State *L) {
	return client_getmetatable(L, 1);
}

static int
lclient_getmetatablev(rlua_State *L) {
	return client_getmetatable(L, 0);
}

static int
client_getuservalue(rlua_State *L, int getref) {
	int n = (int)rluaL_optinteger(L, 2, 1);
	rlua_settop(L, 1);
	lua_State *cL = get_host(L);
	if (get_uservalue(L, cL, n, getref)) {
		rlua_pushboolean(L, 1);
		return 2;
	}
	return 0;
}

static int
lclient_getuservalue(rlua_State *L) {
	return client_getuservalue(L, 1);
}

static int
lclient_getuservaluev(rlua_State *L) {
	return client_getuservalue(L, 0);
}

static int
lclient_getinfo(rlua_State *L) {
	rlua_settop(L, 3);
	size_t optlen = 0;
	const char* options = rluaL_checklstring(L, 2, &optlen);
	if (optlen > 5) {
		return rluaL_error(L, "invalid option");
	}
	int size = 0;
	for (const char* what = options; *what; what++) {
		switch (*what) {
		case 'S': size += 5; break;
		case 'l': size += 1; break;
		case 'n': size += 2; break;
#if LUA_VERSION_NUM >= 502
		case 'u': size += 1; break;
		case 't': size += 1; break;
#endif
#if LUA_VERSION_NUM >= 504
		case 'r': size += 2; break;
#endif
		default: return rluaL_error(L, "invalid option");
		}
	}
	if (rlua_type(L, 3) != LUA_TTABLE) {
		rlua_pop(L, 1);
		rlua_createtable(L, 0, size);
	}

	lua_State *cL = get_host(L);
	lua_Debug ar;

	switch (rlua_type(L, 1)) {
	case LUA_TNUMBER:
		if (lua_getstack(cL, (int)rluaL_checkinteger(L, 1), &ar) == 0)
			return 0;
		if (lua_getinfo(cL, options, &ar) == 0)
			return 0;
		break;
	case LUA_TUSERDATA: {
		rlua_pushvalue(L, 1);
		int t = copy_fromR(L, cL);
		if (t != LUA_TFUNCTION) {
			if (t != LUA_TNONE) {
				lua_pop(cL, 1);	// remove none function
			}
			return rluaL_error(L, "Need a function ref, It's %s", rlua_typename(L, t));
		}
		rlua_pop(L, 1);
		char what[8];
		what[0] = '>';
		strcpy(what+1, options);
		if (lua_getinfo(cL, what, &ar) == 0)
			return 0;
		break;
	}
	default:
		return rluaL_error(L, "Need stack level (integer) or function ref, It's %s", rlua_typename(L, rlua_type(L, 1)));
	}

	for (const char* what = options; *what; what++) {
		switch (*what) {
		case 'S':
#if LUA_VERSION_NUM >= 504
			rlua_pushlstring(L, ar.source, ar.srclen);
#else
			rlua_pushstring(L, ar.source);
#endif
			rlua_setfield(L, 3, "source");
			rlua_pushstring(L, ar.short_src);
			rlua_setfield(L, 3, "short_src");
			rlua_pushinteger(L, ar.linedefined);
			rlua_setfield(L, 3, "linedefined");
			rlua_pushinteger(L, ar.lastlinedefined);
			rlua_setfield(L, 3, "lastlinedefined");
			rlua_pushstring(L, ar.what? ar.what : "?");
			rlua_setfield(L, 3, "what");
			break;
		case 'l':
			rlua_pushinteger(L, ar.currentline);
			rlua_setfield(L, 3, "currentline");
			break;
		case 'n':
			rlua_pushstring(L, ar.name? ar.name : "?");
			rlua_setfield(L, 3, "name");
			if (ar.namewhat) {
				rlua_pushstring(L, ar.namewhat);
			} else {
				rlua_pushnil(L);
			}
			rlua_setfield(L, 3, "namewhat");
			break;
#if LUA_VERSION_NUM >= 502
		case 'u':
			rlua_pushinteger(L, ar.nparams);
			rlua_setfield(L, 3, "nparams");
			break;
		case 't':
			rlua_pushboolean(L, ar.istailcall? 1 : 0);
			rlua_setfield(L, 3, "istailcall");
			break;
#endif
#if LUA_VERSION_NUM >= 504
		case 'r':
			rlua_pushinteger(L, ar.ftransfer);
			rlua_setfield(L, 3, "ftransfer");
			rlua_pushinteger(L, ar.ntransfer);
			rlua_setfield(L, 3, "ntransfer");
			break;
#endif
		}
	}

	return 1;
}

static void
get_registry_value(rlua_State *L, const char* name, int ref) {
	size_t len = strlen(name);
	struct value *v = (struct value *)rlua_newuserdata(L, 3 * sizeof(struct value) + len);
	v->type = VAR::INDEX_INT;
	v->index = ref;
	v++;

	v->type = VAR::INDEX_STR;
	v->index = (int)len;
	v++;
	memcpy(v,name,len);
	v = (struct value *)((char*)v+len);

	v->type = VAR::REGISTRY;
	v->index = 0;
}

static int
lclient_reffunc(rlua_State *L) {
	size_t len = 0;
	const char* func = rluaL_checklstring(L, 1, &len);
	lua_State* cL = get_host(L);
	if (lua::getfield(cL, LUA_REGISTRYINDEX, "__debugger_reffunc") == LUA_TNIL) {
		lua_pop(cL, 1);
		lua_newtable(cL);
		lua_pushvalue(cL, -1);
		lua_setfield(cL, LUA_REGISTRYINDEX, "__debugger_reffunc");
	}
	if (luaL_loadbuffer(cL, func, len, "=")) {
		rlua_pushnil(L);
		rlua_pushstring(L, lua_tostring(cL, -1));
		lua_pop(cL, 2);
		return 2;
	}
	get_registry_value(L, "__debugger_reffunc", luaL_ref(cL, -2));
	lua_pop(cL, 1);
	return 1;
}

static int
lclient_eval(rlua_State *L) {
	lua_State* cL = get_host(L);
	int nargs = rlua_gettop(L);
	if (lua_checkstack(cL, nargs) == 0) {
		return rluaL_error(L, "stack overflow");
	}
	for (int i = 1; i <= nargs; ++i) {
		rlua_pushvalue(L, i);
		int t = copy_fromR(L, cL);
		if (t == LUA_TNONE) {
			lua_pushnil(cL);
		}
		rlua_pop(L, 1);
		if (i == 1 && t != LUA_TFUNCTION) {
			lua_pop(cL, 1);
			return rluaL_error(L, "need function");
		}
	}
	if (debug_pcall(cL, nargs-1, 1, 0)) {
		rlua_pushboolean(L, 0);
		rlua_pushstring(L, lua_tostring(cL, -1));
		lua_pop(cL, 1);
		return 2;
	}
	rlua_pushboolean(L, 1);
	copyvalue(cL, L);
	lua_pop(cL, 1);
	return 2;
}

static int
addwatch(lua_State *cL, int idx) {
	lua_pushvalue(cL, idx);
	if (lua::getfield(cL, LUA_REGISTRYINDEX, "__debugger_watch") == LUA_TNIL) {
		lua_pop(cL, 1);
		lua_newtable(cL);
		lua_pushvalue(cL, -1);
		lua_setfield(cL, LUA_REGISTRYINDEX, "__debugger_watch");
	}
	lua_insert(cL, -2);
	int ref = luaL_ref(cL, -2);
	lua_pop(cL, 1);
	return ref;
}

static int
lclient_watch(rlua_State *L) {
	lua_State* cL = get_host(L);
	int n = lua_gettop(cL);
	int nargs = rlua_gettop(L);
	if (lua_checkstack(cL, nargs) == 0) {
		return rluaL_error(L, "stack overflow");
	}
	for (int i = 1; i <= nargs; ++i) {
		rlua_pushvalue(L, i);
		int t = copy_fromR(L, cL);
		if (t == LUA_TNONE) {
			lua_pushnil(cL);
		}
		rlua_pop(L, 1);
		if (i == 1 && t != LUA_TFUNCTION) {
			lua_pop(cL, 1);
			return rluaL_error(L, "need function");
		}
	}
	if (debug_pcall(cL, nargs-1, LUA_MULTRET, 0)) {
		rlua_pushboolean(L, 0);
		rlua_pushstring(L, lua_tostring(cL, -1));
		lua_pop(cL, 1);
		return 2;
	}
	if (lua_checkstack(cL, 3) == 0) {
		return rluaL_error(L, "stack overflow");
	}
	rlua_pushboolean(L, 1);
	int rets = lua_gettop(cL) - n;
	rluaL_checkstack(L, rets, NULL);
	for (int i = 0; i < rets; ++i) {
		get_registry_value(L, "__debugger_watch", addwatch(cL, i-rets));
	}
	lua_settop(cL, n);
	return 1 + rets;
}

static int
lclient_cleanwatch(rlua_State *L) {
	lua_State* cL = get_host(L);
	lua_pushnil(cL);
	lua_setfield(cL, LUA_REGISTRYINDEX, "__debugger_watch");
	return 0;
}

static const char* costatus(lua_State* L, lua_State* co) {
	if (L == co) return "running";
	switch (lua_status(co)) {
	case LUA_YIELD:
		return "suspended";
	case LUA_OK: {
		lua_Debug ar;
		if (lua_getstack(co, 0, &ar)) return "normal";
		if (lua_gettop(co) == 0) return "dead";
		return "suspended";
	}
	default:
		return "dead";
	}
}

static int
lclient_costatus(rlua_State *L) {
	lua_State* cL = get_host(L);
	if (copy_fromR(L, cL) == LUA_TNONE) {
		rlua_pushstring(L, "invalid");
		return 1;
	}
	if (lua_type(cL, -1) != LUA_TTHREAD) {
		lua_pop(cL, 1);
		rlua_pushstring(L, "invalid");
		return 1;
	}
	const char* s = costatus(cL, lua_tothread(cL, -1));
	lua_pop(cL, 1);
	rlua_pushstring(L, s);
	return 1;
}

int
init_visitor(rlua_State *L) {
	rluaL_Reg l[] = {
		{ "getlocal", lclient_getlocal },
		{ "getlocalv", lclient_getlocalv },
		{ "getfunc", lclient_getfunc },
		{ "getupvalue", lclient_getupvalue },
		{ "getupvaluev", lclient_getupvaluev },
		{ "getmetatable", lclient_getmetatable },
		{ "getmetatablev", lclient_getmetatablev },
		{ "getuservalue", lclient_getuservalue },
		{ "getuservaluev", lclient_getuservaluev },
		{ "index", lclient_index },
		{ "indexv", lclient_indexv },
		{ "field", lclient_field },
		{ "fieldv", lclient_fieldv },
		{ "getstack", lclient_getstack },
		{ "tablehash", lclient_tablehash },
		{ "tablehashv", lclient_tablehashv },
		{ "tablesize", lclient_tablesize },
		{ "tablekey", lclient_tablekey },
		{ "value", lclient_value },
		{ "assign", lclient_assign },
		{ "type", lclient_type },
		{ "getinfo", lclient_getinfo },
		{ "reffunc", lclient_reffunc },
		{ "eval", lclient_eval },
		{ "watch", lclient_watch },
		{ "cleanwatch", lclient_cleanwatch },
		{ "costatus", lclient_costatus },
		{ NULL, NULL },
	};
	rlua_newtable(L);
	rluaL_setfuncs(L,l,0);
	get_registry(L, VAR::GLOBAL);
	rlua_setfield(L, -2, "_G");
	get_registry(L, VAR::REGISTRY);
	rlua_setfield(L, -2, "_REGISTRY");
	return 1;
}

RLUA_FUNC
int luaopen_remotedebug_visitor(rlua_State *L) {
	get_host(L);
	return init_visitor(L);
}
