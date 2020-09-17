#include "rlua.h"

static int DEBUG_HOST = 0;	// host L in client VM
static int DEBUG_CLIENT = 0;	// client L in host VM for hook

int  event(rlua_State* cL, lua_State* hL, const char* name);

rlua_State *
get_client(lua_State *L) {
	if (lua::rawgetp(L, LUA_REGISTRYINDEX, &DEBUG_CLIENT) != LUA_TLIGHTUSERDATA) {
		lua_pop(L, 1);
		return 0;
	}
	rlua_State *cL = (rlua_State *)lua_touserdata(L, -1);
	lua_pop(L, 1);
	return cL;
}

void
set_host(rlua_State* L, lua_State* hL) {
    rlua_pushlightuserdata(L, hL);
    rlua_rawsetp(L, RLUA_REGISTRYINDEX, &DEBUG_HOST);
}

lua_State *
get_host(rlua_State *L) {
	if (rlua_rawgetp(L, RLUA_REGISTRYINDEX, &DEBUG_HOST) != LUA_TLIGHTUSERDATA) {
		rlua_pushstring(L, "Must call in debug client");
		rlua_error(L);
		return 0;
	}
	lua_State *hL = (lua_State *)rlua_touserdata(L, -1);
	rlua_pop(L, 1);
	return hL;
}

static void
clear_client(lua_State *L) {
	rlua_State *cL = get_client(L);
	lua_pushnil(L);
	lua_rawsetp(L, LUA_REGISTRYINDEX, &DEBUG_CLIENT);
	if (cL) {
		rlua_close(cL);
	}
}

static int
lhost_clear(lua_State *L) {
	rlua_State *cL = get_client(L);
	if (cL) {
		event(cL, L, "exit");
	}
	clear_client(L);
	return 0;
}

// 1. lightuserdata string_mainscript
// 2. lightuserdata host_L
static int
client_main(rlua_State *L) {
	lua_State *hL = (lua_State *)rlua_touserdata(L, 2);
	set_host(L, hL);
	rlua_pushboolean(L, 1);
	rlua_setfield(L, RLUA_REGISTRYINDEX, "LUA_NOENV");
	rluaL_openlibs(L);
#if !defined(RLUA_DISABLE) || LUA_VERSION_NUM >= 504
#	if !defined(LUA_GCGEN)
#		define LUA_GCGEN 10
#	endif
	rlua_gc(L, LUA_GCGEN, 0, 0);
#endif
	const char* mainscript = (const char *)rlua_touserdata(L, 1);
	if (rluaL_loadstring(L, mainscript) != LUA_OK) {
		return rlua_error(L);
	}
	rlua_pushvalue(L, 3);
	rlua_call(L, 1, 0);
	return 0;
}

static void
push_errmsg(lua_State *L, rlua_State *cL) {
	if (rlua_type(cL, -1) != LUA_TSTRING) {
		lua_pushstring(L, "Unknown Error");
	} else {
		size_t sz = 0;
		const char * err = rlua_tolstring(cL, -1, &sz);
		lua_pushlstring(L, err, sz);
	}
}

static int
lhost_start(lua_State *L) {
	clear_client(L);
	lua_CFunction preprocessor = NULL;
	const char * mainscript = luaL_checkstring(L, 1);
	if (lua_type(L, 2) == LUA_TFUNCTION) {
		preprocessor = lua_tocfunction(L, 2);
		if (preprocessor == NULL) {
			lua_pushstring(L, "Preprocessor must be a C function");
			return lua_error(L);
		}
		if (lua_getupvalue(L, 2, 1)) {
			lua_pushstring(L, "Preprocessor must be a light C function (no upvalue)");
			return lua_error(L);
		}
	}
	rlua_State *cL = rluaL_newstate();
	if (cL == NULL) {
		lua_pushstring(L, "Can't new debug client");
		return lua_error(L);
	}

	lua_pushlightuserdata(L, cL);
	lua_rawsetp(L, LUA_REGISTRYINDEX, &DEBUG_CLIENT);

	rlua_pushcfunction(cL, client_main);
	rlua_pushlightuserdata(cL, (void *)mainscript);
	rlua_pushlightuserdata(cL, (void *)L);
	if (preprocessor) {
		//TODO: convert C function？
		rlua_pushcfunction(cL, (rlua_CFunction)preprocessor);
	} else {
		rlua_pushnil(cL);
	}

	if (rlua_pcall(cL, 3, 0, 0) != LUA_OK) {
		push_errmsg(L, cL);
		clear_client(L);
		return lua_error(L);
	}
	return 0;
}

static int
lhost_event(lua_State *L) {
	rlua_State* cL = get_client(L);
	if (!cL) {
		return 0;
	}
	int ok = event(cL, L, luaL_checkstring(L, 1));
	if (ok < 0) {
		return 0;
	}
	lua_pushboolean(L, ok);
	return 1;
}

#if defined(_WIN32) && !defined(RLUA_DISABLE)
#include <bee/utility/unicode_win.h>
#include <bee/lua/binding.h>

static int
la2u(lua_State *L) {
    std::string r = bee::a2u(bee::lua::to_strview(L, 1));
    lua_pushlstring(L, r.data(), r.size());
    return 1;
}
#endif

RLUA_FUNC
int luaopen_remotedebug(lua_State *L) {
	luaL_Reg l[] = {
		{ "start", lhost_start },
		{ "clear", lhost_clear },
		{ "event", lhost_event },
#if defined(_WIN32) && !defined(RLUA_DISABLE)
		{ "a2u",   la2u },
#endif
		{ NULL, NULL },
	};
#if LUA_VERSION_NUM == 501
	luaL_register(L, "remotedebug", l);
	lua_newuserdata(L, 0);
#else
	luaL_newlibtable(L,l);
	luaL_setfuncs(L,l,0);
#endif

	lua_createtable(L,0,1);
	lua_pushcfunction(L, lhost_clear);
	lua_setfield(L, -2, "__gc");
	lua_setmetatable(L, -2);

#if LUA_VERSION_NUM == 501
	lua_rawseti(L, -2, 0);
#endif
	return 1;
}
