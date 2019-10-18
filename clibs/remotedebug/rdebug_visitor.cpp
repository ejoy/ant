#include "rdebug_debugvar.h"
#include "rdebug_table.h"
#include <string.h>
#include <stdio.h>

static int DEBUG_WATCH = 0;
static int DEBUG_WATCH_FUNC = 0;

lua_State* get_host(rlua_State *L);

// frame, index
// return value, name
static int
client_getlocal(rlua_State *L, int getref) {
	int frame = (int)rluaL_checkinteger(L, 1);
	int index = (int)rluaL_checkinteger(L, 2);

	lua_State *hL = get_host(L);

	const char *name = get_frame_local(L, hL, frame, index, getref);
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

	lua_State *hL = get_host(L);

	if (get_frame_func(L, hL, frame)) {
		return 1;
	}

	return 0;
}

static int
client_index(rlua_State *L, int getref) {
	lua_State *hL = get_host(L);
	if (rlua_gettop(L) != 2)
		return rluaL_error(L, "need table key");

	if (get_index(L, hL, getref)) {
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
lclient_nextkey(rlua_State *L) {
	lua_State *hL = get_host(L);
	rlua_settop(L, 2);
	rlua_pushvalue(L, 1);
	// table key table
	rlua_insert(L, -2);
	// table table key
	if (next_key(L, hL, 0) == 0)
		return 0;
	// table key_obj
	return 1;
}

static int
client_getstack(rlua_State *L, int getref) {
	int index = (int)rluaL_checkinteger(L, 1);
	lua_State *hL = get_host(L);
	if (get_stack(L, hL, index, getref)) {
		return 1;
	}
	return 0;
}

static int
lclient_getstack(rlua_State *L) {
	return client_getstack(L, 1);
}

static int
lclient_getstackv(rlua_State *L) {
	return client_getstack(L, 0);
}

static int
lclient_copytable(rlua_State *L) {
	lua_State *hL = get_host(L);
	rlua_Integer maxn = rluaL_optinteger(L, 2, 0xffff);
	rlua_settop(L, 1);
	if (lua_checkstack(hL, 4) == 0) {
		return rluaL_error(L, "stack overflow");
	}
	if (eval_value(L, hL) != LUA_TTABLE) {
		lua_pop(hL, 1);	// pop table
		return 0;
	}
	const void* t = lua_topointer(hL, -1);
	if (!t) {
		lua_pop(hL, 1);
		return 0;
	}
	rlua_newtable(L);
	unsigned int hsize = remotedebug::table::hash_size(t);
	for (unsigned int i = 0; i < hsize; ++i) {
		if (remotedebug::table::get_kv(hL, t, i)) {
			if (--maxn < 0) {
				lua_pop(hL, 2);
				return 1;
			}
			rlua_pushvalue(L, 1); combine_kv(L, hL, 0, VAR_INDEX_KEY, i);
			rlua_pushvalue(L, 1); combine_kv(L, hL, 1, VAR_INDEX_VAL, i);
			rlua_rawset(L, -3);
		}
	}
	return 1;
}

int lclient_tablesize(rlua_State *L) {
	lua_State* hL = get_host(L);
	if (eval_value(L, hL) != LUA_TTABLE) {
		lua_pop(hL, 1);
		return 0;
	}
	const void* t = lua_topointer(hL, -1);
	if (!t) {
		lua_pop(hL, 1);
		return 0;
	}
	rlua_pushinteger(L, remotedebug::table::array_size(t));
	rlua_pushinteger(L, remotedebug::table::hash_size(t));
	lua_pop(hL, 1);
	return 2;
}

static int
lclient_value(rlua_State *L) {
	lua_State *hL = get_host(L);
	rlua_settop(L, 1);
	get_value(L, hL);
	return 1;
}

static int
lclient_tostring(rlua_State *L) {
	lua_State *hL = get_host(L);
	rlua_settop(L, 1);
	tostring(L, hL);
	return 1;
}

// userdata ref
// any value
// ref = value
static int
lclient_assign(rlua_State *L) {
	lua_State *hL = get_host(L);
	if (lua_checkstack(hL, 2) == 0)
		return rluaL_error(L, "stack overflow");
	rlua_settop(L, 2);
	int vtype = rlua_type(L, 2);
	switch (vtype) {
	case LUA_TNUMBER:
	case LUA_TNIL:
	case LUA_TBOOLEAN:
	case LUA_TLIGHTUSERDATA:
	case LUA_TSTRING:
		copy_fromX(L, hL);
		break;
	case LUA_TUSERDATA:
		if (eval_value(L, hL) == LUA_TNONE) {
			lua_pushnil(hL);
		}
		break;
	default:
		return rluaL_error(L, "Invalid value type %s", rlua_typename(L, vtype));
	}
	rluaL_checktype(L, 1, LUA_TUSERDATA);
	struct value * ref = (struct value *)rlua_touserdata(L, 1);
	rlua_getuservalue(L, 1);
	int r = assign_value(L, ref, hL);
	rlua_pushboolean(L, r);
	return 1;
}

static int
lclient_type(rlua_State *L) {
	lua_State *hL = get_host(L);

	int t = eval_value(L, hL);
	rlua_pushstring(L, rlua_typename(L, t));
	switch (t) {
	case LUA_TFUNCTION:
		if (lua_iscfunction(hL, -1)) {
			rlua_pushstring(L, "c");
		} else {
			rlua_pushstring(L, "lua");
		}
		break;
	case LUA_TNUMBER:
#if LUA_VERSION_NUM >= 503
		if (lua_isinteger(hL, -1)) {
			rlua_pushstring(L, "integer");
		} else {
			rlua_pushstring(L, "float");
		}
#else
		rlua_pushstring(L, "float");
#endif
		break;
	case LUA_TUSERDATA:
		rlua_pushstring(L, "full");
		break;
	case LUA_TLIGHTUSERDATA:
		rlua_pushstring(L, "light");
		break;
	default:
		lua_pop(hL, 1);
		return 1;
	}
	lua_pop(hL, 1);
	return 2;
}

static int
client_getupvalue(rlua_State *L, int getref) {
	int index = (int)rluaL_checkinteger(L, 2);
	rlua_settop(L, 1);
	lua_State *hL = get_host(L);

	const char *name = get_upvalue(L, hL, index, getref);
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
	lua_State *hL = get_host(L);
	if (get_metatable(L, hL, getref)) {
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
	lua_State *hL = get_host(L);
	if (get_uservalue(L, hL, n, getref)) {
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

	lua_State *hL = get_host(L);
	lua_Debug ar;

	switch (rlua_type(L, 1)) {
	case LUA_TNUMBER:
		if (lua_getstack(hL, (int)rluaL_checkinteger(L, 1), &ar) == 0)
			return 0;
		if (lua_getinfo(hL, options, &ar) == 0)
			return 0;
		break;
	case LUA_TUSERDATA: {
		rlua_pushvalue(L, 1);
		int t = eval_value(L, hL);
		if (t != LUA_TFUNCTION) {
			if (t != LUA_TNONE) {
				lua_pop(hL, 1);	// remove none function
			}
			return rluaL_error(L, "Need a function ref, It's %s", rlua_typename(L, t));
		}
		rlua_pop(L, 1);
		char what[8];
		what[0] = '>';
		strcpy(what+1, options);
		if (lua_getinfo(hL, what, &ar) == 0)
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

static int
lclient_reffunc(rlua_State *L) {
	size_t len = 0;
	const char* func = rluaL_checklstring(L, 1, &len);
	lua_State* hL = get_host(L);
	if (lua::rawgetp(hL, LUA_REGISTRYINDEX, &DEBUG_WATCH_FUNC) == LUA_TNIL) {
		lua_pop(hL, 1);
		lua_newtable(hL);
		lua_pushvalue(hL, -1);
		lua_rawsetp(hL, LUA_REGISTRYINDEX, &DEBUG_WATCH_FUNC);
	}
	if (luaL_loadbuffer(hL, func, len, "=")) {
		rlua_pushnil(L);
		rlua_pushstring(L, lua_tostring(hL, -1));
		lua_pop(hL, 2);
		return 2;
	}
	rlua_pushinteger(L, luaL_ref(hL, -2));
	lua_pop(hL, 1);
	return 1;
}

static int
getreffunc(lua_State *hL, lua_Integer func) {
	if (lua::rawgetp(hL, LUA_REGISTRYINDEX, &DEBUG_WATCH_FUNC) != LUA_TTABLE) {
		lua_pop(hL, 1);
		return 0;
	}
#if LUA_VERSION_NUM >= 503
	if (lua::rawgeti(hL, -1, func) != LUA_TFUNCTION) {
#else
	if (lua::rawgeti(hL, -1, (int)func) != LUA_TFUNCTION) {
#endif
		lua_pop(hL, 2);
		return 0;
	}
	lua_remove(hL, -2);
	return 1;
}

static int
lclient_eval(rlua_State *L) {
	rlua_Integer func = rluaL_checkinteger(L, 1);
	const char* source = rluaL_checkstring(L, 2);
	rlua_Integer level = rluaL_checkinteger(L, 3);
	lua_State* hL = get_host(L);
	if (!getreffunc(hL, (lua_Integer)func)) {
		rlua_pushboolean(L, 0);
		rlua_pushstring(L, "invalid func");
		return 2;
	}
	lua_pushstring(hL, source);
	lua_pushinteger(hL, (lua_Integer)level);
	if (lua_pcall(hL, 2, 1, 0)) {
		rlua_pushboolean(L, 0);
		rlua_pushstring(L, lua_tostring(hL, -1));
		lua_pop(hL, 1);
		return 2;
	}
	rlua_pushboolean(L, 1);
	copyvalue(hL, L);
	lua_pop(hL, 1);
	return 2;
}

static int
lclient_evalref(rlua_State *L) {
	lua_State* hL = get_host(L);
	int n = rlua_gettop(L);
	for (int i = 1; i <= n; ++i) {
		rlua_pushvalue(L, i);
		int t = eval_value(L, hL);
		rlua_pop(L, 1);
		if (i == 1 && t != LUA_TFUNCTION) {
			lua_pop(hL, 1);
			return rluaL_error(L, "need function");
		}
	}

	if (lua_pcall(hL, n-1, 1, 0)) {
		rlua_pushboolean(L, 0);
		rlua_pushstring(L, lua_tostring(hL, -1));
		lua_pop(hL, 1);
		return 2;
	}
	rlua_pushboolean(L, 1);
	copyvalue(hL, L);
	lua_pop(hL, 1);
	return 2;
}

static int
addwatch(lua_State *hL, int idx) {
	lua_pushvalue(hL, idx);
	if (lua::rawgetp(hL, LUA_REGISTRYINDEX, &DEBUG_WATCH) == LUA_TNIL) {
		lua_pop(hL, 1);
		lua_newtable(hL);
		lua_pushvalue(hL, -1);
		lua_rawsetp(hL, LUA_REGISTRYINDEX, &DEBUG_WATCH);
	}
	lua_insert(hL, -2);
	int ref = luaL_ref(hL, -2);
	lua_pop(hL, 1);
	return ref;
}

static int
storewatch(rlua_State *L, lua_State *hL, int idx) {
	int ref = addwatch(hL, idx);
	lua_remove(hL, idx);
	get_registry(L, VAR_REGISTRY);
	rlua_pushlightuserdata(L, &DEBUG_WATCH);
	if (!get_index(L, hL, 1)) {
		return 0;
	}
	rlua_pushinteger(L, ref);
	if (!get_index(L, hL, 1)) {
		return 0;
	}
	return 1;
}

static int
lclient_evalwatch(rlua_State *L) {
	rlua_Integer func = rluaL_checkinteger(L, 1);
	const char* source = rluaL_checkstring(L, 2);
	rlua_Integer level = rluaL_checkinteger(L, 3);
	lua_State* hL = get_host(L);
	if (!getreffunc(hL, (lua_Integer)func)) {
		rlua_pushboolean(L, 0);
		rlua_pushstring(L, "invalid func");
		return 2;
	}
	lua_pushstring(hL, source);
	lua_pushinteger(hL, (lua_Integer)level);
	int n = lua_gettop(hL) - 3;
	if (lua_pcall(hL, 2, LUA_MULTRET, 0)) {
		rlua_pushboolean(L, 0);
		rlua_pushstring(L, lua_tostring(hL, -1));
		lua_pop(hL, 1);
		return 2;
	}
	int rets = lua_gettop(hL) - n;
	for (int i = 0; i < rets; ++i) {
		if (!storewatch(L, hL, i-rets)) {
			rlua_pushboolean(L, 0);
			rlua_pushstring(L, "error");
			return 2;
		}
	}
	rlua_pushboolean(L, 1);
	rlua_insert(L, -1-rets);
	return 1 + rets;
}

static int
lclient_unwatch(rlua_State *L) {
	rlua_Integer ref = rluaL_checkinteger(L, 1);
	lua_State* hL = get_host(L);
	if (lua::rawgetp(hL, LUA_REGISTRYINDEX, &DEBUG_WATCH) == LUA_TNIL) {
		return 0;
	}
	luaL_unref(hL, -1, (int)ref);
	return 0;
}

static int
lclient_cleanwatch(rlua_State *L) {
	lua_State* hL = get_host(L);
	lua_pushnil(hL);
	lua_rawsetp(hL, LUA_REGISTRYINDEX, &DEBUG_WATCH);
	return 0;
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
		{ "nextkey", lclient_nextkey },
		{ "getstack", lclient_getstack },
		{ "getstackv", lclient_getstackv },
		{ "copytable", lclient_copytable },
		{ "tablesize", lclient_tablesize },
		{ "value", lclient_value },
		{ "tostring", lclient_tostring },
		{ "assign", lclient_assign },
		{ "type", lclient_type },
		{ "getinfo", lclient_getinfo },
		{ "reffunc", lclient_reffunc },
		{ "eval", lclient_eval },
		{ "evalref", lclient_evalref },
		{ "evalwatch", lclient_evalwatch },
		{ "unwatch", lclient_unwatch },
		{ "cleanwatch", lclient_cleanwatch },
		{ NULL, NULL },
	};
	rlua_newtable(L);
	rluaL_setfuncs(L,l,0);
	get_registry(L, VAR_GLOBAL);
	rlua_setfield(L, -2, "_G");
	get_registry(L, VAR_REGISTRY);
	rlua_setfield(L, -2, "_REGISTRY");
	return 1;
}

RLUA_FUNC
int luaopen_remotedebug_visitor(rlua_State *L) {
	get_host(L);
	return init_visitor(L);
}
