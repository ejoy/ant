#include <lua.hpp>
#include "rdebug_delayload.h"

static int DEBUG_HOST = 0;	// host L in client VM
static int DEBUG_CLIENT = 0;	// client L in host VM for hook

void probe(lua_State* cL, lua_State* hL, const char* name);
int  event(lua_State* cL, lua_State* hL, const char* name);

lua_State *
get_client(lua_State *L) {
	if (lua_rawgetp(L, LUA_REGISTRYINDEX, &DEBUG_CLIENT) != LUA_TLIGHTUSERDATA) {
		return 0;
	}
	lua_State *cL = (lua_State *)lua_touserdata(L, -1);
	lua_pop(L, 1);
	return cL;
}

void
set_host(lua_State* L, lua_State* hL) {
    lua_pushlightuserdata(L, hL);
    lua_rawsetp(L, LUA_REGISTRYINDEX, &DEBUG_HOST);
}

lua_State *
get_host(lua_State *L) {
	if (lua_rawgetp(L, LUA_REGISTRYINDEX, &DEBUG_HOST) != LUA_TLIGHTUSERDATA) {
		lua_pushstring(L, "Must call in debug client");
		lua_error(L);
		return 0;
	}
	lua_State *hL = (lua_State *)lua_touserdata(L, -1);
	lua_pop(L, 1);
	return hL;
}

static void
clear_client(lua_State *L) {
	lua_State *cL = get_client(L);
	lua_pushnil(L);
	lua_rawsetp(L, LUA_REGISTRYINDEX, &DEBUG_CLIENT);
	if (cL) {
		lua_close(cL);
	}
}

static int
lhost_clear(lua_State *L) {
	clear_client(L);
	return 0;
}

// 1. lightuserdata string_mainscript
// 2. lightuserdata host_L
static int
client_main(lua_State *L) {
	lua_State *hL = (lua_State *)lua_touserdata(L, 2);
	set_host(L, hL);
	luaL_openlibs(L);
	const char* mainscript = (const char *)lua_touserdata(L, 1);
	if (luaL_loadstring(L, mainscript) != LUA_OK) {
		return lua_error(L);
	}
	lua_pushvalue(L, 3);
	lua_call(L, 1, 0);
	return 0;
}

static void
push_errmsg(lua_State *L, lua_State *cL) {
	if (lua_type(cL, -1) != LUA_TSTRING) {
		lua_pushstring(L, "Unknown Error");
	} else {
		size_t sz = 0;
		const char * err = lua_tolstring(cL, -1, &sz);
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
	lua_State *cL = luaL_newstate();
	if (cL == NULL) {
		lua_pushstring(L, "Can't new debug client");
		return lua_error(L);
	}

	lua_pushlightuserdata(L, cL);
	lua_rawsetp(L, LUA_REGISTRYINDEX, &DEBUG_CLIENT);

	lua_pushcfunction(cL, client_main);
	lua_pushlightuserdata(cL, (void *)mainscript);
	lua_pushlightuserdata(cL, (void *)L);
	if (preprocessor) {
		lua_pushcfunction(cL, preprocessor);
	} else {
		lua_pushnil(cL);
	}

	if (lua_pcall(cL, 3, 0, 0) != LUA_OK) {
		push_errmsg(L, cL);
		clear_client(L);
		return lua_error(L);
	}
	return 0;
}

static int
lhost_probe(lua_State *L) {
	probe(get_client(L), L, luaL_checkstring(L, 1));
	return 0;
}

static int
lhost_event(lua_State *L) {
	int ok = event(get_client(L), L, luaL_checkstring(L, 1));
	if (ok < 0) {
		return 0;
	}
	lua_pushboolean(L, ok);
	return 1;
}

extern "C" 
#if defined(_WIN32)
__declspec(dllexport)
#endif
int luaopen_remotedebug(lua_State *L) {
#if defined(_MSC_VER)
	remotedebug::delayload::caller_is_luadll(_ReturnAddress());
#endif
	luaL_Reg l[] = {
		{ "start", lhost_start },
		{ "clear", lhost_clear },
		{ "probe", lhost_probe },
		{ "event", lhost_event },
		{ NULL, NULL },
	};
	luaL_newlibtable(L,l);
	luaL_setfuncs(L,l,0);

	lua_createtable(L,0,1);
	lua_pushcfunction(L, lhost_clear);
	lua_setfield(L, -2, "__gc");
	lua_setmetatable(L, -2);
	return 1;
}
