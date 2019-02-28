#define LUA_LIB
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include <string.h>
#include <stdio.h>

#include "debugvar.h"

lua_State* get_host(lua_State *L);

// frame, index
// return value, name
static int
client_getlocal(lua_State *L, int getref) {
	int frame = (int)luaL_checkinteger(L, 1);
	int index = (int)luaL_checkinteger(L, 2);

	lua_State *hL = get_host(L);

	const char *name = get_frame_local(L, hL, frame, index, getref);
	if (name) {
		lua_pushstring(L, name);
		lua_insert(L, -2);
		return 2;
	}

	return 0;
}

static int
lclient_getlocal(lua_State *L) {
	return client_getlocal(L, 1);
}

static int
lclient_getlocalv(lua_State *L) {
	return client_getlocal(L, 0);
}

// frame
// return func
static int
lclient_getfunc(lua_State *L) {
	int frame = (int)luaL_checkinteger(L, 1);

	lua_State *hL = get_host(L);

	if (get_frame_func(L, hL, frame)) {
		return 1;
	}

	return 0;
}

static int
client_index(lua_State *L, int getref) {
	lua_State *hL = get_host(L);
	if (lua_gettop(L) != 2)
		return luaL_error(L, "need table key");

	if (get_index(L, hL, getref)) {
		return 1;
	}
	return 0;
}

static int
lclient_index(lua_State *L) {
	return client_index(L, 1);
}

static int
lclient_indexv(lua_State *L) {
	return client_index(L, 0);
}

static int
client_next(lua_State *L, int getref) {
	lua_State *hL = get_host(L);
	lua_settop(L, 2);
	lua_pushvalue(L, 1);
	// table key table
	lua_insert(L, -2);
	// table table key
	if (next_key(L, hL, getref) == 0)
		return 0;
	// table key_obj
	lua_insert(L, 1);
	// key_obj table
	lua_pushvalue(L, 1);
	// key_obj table key_obj
	if (get_index(L, hL, getref) == 0) {
		return 0;
	}
	return 2;
}

static int
lclient_next(lua_State *L) {
	return client_next(L, 1);
}

static int
lclient_nextv(lua_State *L) {
	return client_next(L, 0);
}

static int
lclient_copytable(lua_State *L) {
	lua_State *hL = get_host(L);
	lua_settop(L, 1);
	if (lua_checkstack(hL, 4) == 0) {
		return luaL_error(L, "stack overflow");
	}
	if (eval_value(L, hL) != LUA_TTABLE) {
		lua_pop(hL, 1);	// pop table
		return 0;
	}
	lua_newtable(L);
	lua_insert(L, -2);
	lua_pushnil(L);
	// L : result tableref nil
	lua_pushnil(hL);
	// hL : table nil
	while(next_kv(L, hL)) {
		// L: result tableref nextkey value
		lua_pushvalue(L, -2);
		lua_insert(L, -2);
		// L: result tableref nextkey nextkey value
		lua_rawset(L, -5);
		// L: result tableref nextkey
	}
	return 1;
}

static int
lclient_value(lua_State *L) {
	lua_State *hL = get_host(L);
	lua_settop(L, 1);
	get_value(L, hL);
	return 1;
}

// userdata ref
// any value
// ref = value
static int
lclient_assign(lua_State *L) {
	lua_State *hL = get_host(L);
	if (lua_checkstack(hL, 2) == 0)
		return luaL_error(L, "stack overflow");
	lua_settop(L, 2);
	int vtype = lua_type(L, 2);
	switch (vtype) {
	case LUA_TNUMBER:
	case LUA_TNIL:
	case LUA_TBOOLEAN:
	case LUA_TLIGHTUSERDATA:
	case LUA_TSTRING:
		copy_value(L, hL);
		break;
	case LUA_TUSERDATA:
		if (eval_value(L, hL) == LUA_TNONE) {
			lua_pushnil(hL);
		}
		break;
	default:
		return luaL_error(L, "Invalid value type %s", lua_typename(L, vtype));
	}
	luaL_checktype(L, 1, LUA_TUSERDATA);
	struct value * ref = lua_touserdata(L, 1);
	lua_getuservalue(L, 1);
	int r = assign_value(L, ref, hL);
	lua_pushboolean(L, r);
	return 1;
}

static int
lclient_type(lua_State *L) {
	lua_State *hL = get_host(L);

	int t = eval_value(L, hL);
	lua_pushstring(L, lua_typename(L, t));
	switch (t) {
	case LUA_TFUNCTION:
		if (lua_iscfunction(hL, -1)) {
			lua_pushstring(L, "c");
		} else {
			lua_pushstring(L, "lua");
		}
		break;
	case LUA_TNUMBER:
		if (lua_isinteger(hL, -1)) {
			lua_pushstring(L, "integer");
		} else {
			lua_pushstring(L, "float");
		}
		break;
	case LUA_TUSERDATA:
		lua_pushstring(L, "full");
		break;
	case LUA_TLIGHTUSERDATA:
		lua_pushstring(L, "light");
		break;
	default:
		lua_pop(hL, 1);
		return 1;
	}
	lua_pop(hL, 1);
	return 2;
}

static int
client_getupvalue(lua_State *L, int getref) {
	int index = (int)luaL_checkinteger(L, 2);
	lua_settop(L, 1);
	lua_State *hL = get_host(L);

	const char *name = get_upvalue(L, hL, index, getref);
	if (name) {
		lua_pushstring(L, name);
		lua_insert(L, -2);
		return 2;
	}

	return 0;
}

static int
lclient_getupvalue(lua_State *L) {
	return client_getupvalue(L, 1);
}

static int
lclient_getupvaluev(lua_State *L) {
	return client_getupvalue(L, 0);
}

static int
client_getmetatable(lua_State *L, int getref) {
	lua_settop(L, 1);
	lua_State *hL = get_host(L);
	if (get_metatable(L, hL, getref)) {
		return 1;
	}
	return 0;
}

static int
lclient_getmetatable(lua_State *L) {
	return client_getmetatable(L, 1);
}

static int
lclient_getmetatablev(lua_State *L) {
	return client_getmetatable(L, 0);
}

static int
client_getuservalue(lua_State *L, int getref) {
	lua_settop(L, 1);
	lua_State *hL = get_host(L);
	if (get_uservalue(L, hL, getref)) {
		return 1;
	}
	return 0;
}

static int
lclient_getuservalue(lua_State *L) {
	return client_getuservalue(L, 1);
}

static int
lclient_getuservaluev(lua_State *L) {
	return client_getuservalue(L, 0);
}

static int
lclient_getinfo(lua_State *L) {
	lua_settop(L, 2);
	if (lua_type(L, 2) != LUA_TTABLE) {
		lua_pop(L, 1);
		lua_createtable(L, 0, 7);
	}
	lua_State *hL = get_host(L);
	lua_Debug ar;

	switch (lua_type(L, 1)) {
	case LUA_TNUMBER:
		if (lua_getstack(hL, (int)luaL_checkinteger(L, 1), &ar) == 0)
			return 0;
		if (lua_getinfo(hL, "Slnt", &ar) == 0)
			return 0;
		break;
	case LUA_TUSERDATA: {
		lua_pushvalue(L, 1);
		int t = eval_value(L, hL);
		if (t != LUA_TFUNCTION) {
			if (t != LUA_TNONE) {
				lua_pop(hL, 1);	// remove none function
			}
			return luaL_error(L, "Need a function ref, It's %s", lua_typename(L, t));
		}
		lua_pop(L, 1);
		if (lua_getinfo(hL, ">Slnt", &ar) == 0)
			return 0;
		break;
	}
	default:
		return luaL_error(L, "Need stack level (integer) or function ref, It's %s", lua_typename(L, lua_type(L, 1)));
	}

	lua_pushstring(L, ar.source);
	lua_setfield(L, 2, "source");
	lua_pushstring(L, ar.short_src);
	lua_setfield(L, 2, "short_src");
	lua_pushinteger(L, ar.currentline);
	lua_setfield(L, 2, "currentline");
	lua_pushinteger(L, ar.linedefined);
	lua_setfield(L, 2, "linedefined");
	lua_pushinteger(L, ar.lastlinedefined);
	lua_setfield(L, 2, "lastlinedefined");
	lua_pushstring(L, ar.name? ar.name : "?");
	lua_setfield(L, 2, "name");
	lua_pushstring(L, ar.what? ar.what : "?");
	lua_setfield(L, 2, "what");
	if (ar.namewhat) {
		lua_pushstring(L, ar.namewhat);
	} else {
		lua_pushnil(L);
	}
	lua_setfield(L, 2, "namewhat");
	lua_pushboolean(L, ar.istailcall? 1 : 0);
	lua_setfield(L, 2, "istailcall");

	return 1;
}

int
init_visitor(lua_State *L) {
	// It's client
	luaL_Reg l[] = {
		{ "getlocal", lclient_getlocal },
		{ "getlocalv", lclient_getlocalv },
		{ "getfunc", lclient_getfunc },
		{ "getupvalue", lclient_getupvalue },
		{ "getupvaluev", lclient_getupvaluev },
		{ "getmetatable", lclient_getmetatable },
		{ "getmetatablev", lclient_getmetatablev },
		{ "getuservalue", lclient_getuservalue },
		{ "getuservaluev", lclient_getuservaluev },
		{ "detail", show_detail },
		{ "index", lclient_index },
		{ "indexv", lclient_indexv },
		{ "next", lclient_next },
		{ "nextv", lclient_nextv },
		{ "copytable", lclient_copytable },
		{ "value", lclient_value },
		{ "assign", lclient_assign },
		{ "type", lclient_type },
		{ "getinfo", lclient_getinfo },
		{ NULL, NULL },
	};
	luaL_newlib(L,l);
	get_registry(L, VAR_GLOBAL);
	lua_setfield(L, -2, "_G");
	get_registry(L, VAR_REGISTRY);
	lua_setfield(L, -2, "_REGISTRY");
	get_registry(L, VAR_MAINTHREAD);
	lua_setfield(L, -2, "_MAINTHREAD");
	return 1;
}

LUAMOD_API int
luaopen_remotedebug_visitor(lua_State *L) {
	luaL_checkversion(L);
	get_host(L);
	return init_visitor(L);
}

lua_State *
getthread(lua_State *L) {
	luaL_checktype(L, 1, LUA_TUSERDATA);
	lua_State *hL = get_host(L);
	lua_pushvalue(L, 1);
	int ct = eval_value(L, hL);
	lua_pop(L, 1);
	if (ct == LUA_TNONE) {
		luaL_error(L, "Invalid thread");
		return NULL;
	}
	if (ct != LUA_TTHREAD) {
		lua_pop(hL, 1);
		luaL_error(L, "Need coroutine, Is %s", lua_typename(hL, ct));
		return NULL;
	}
	lua_State *co = lua_tothread(hL, -1);
	lua_pop(hL, 1);
	return co;
}
