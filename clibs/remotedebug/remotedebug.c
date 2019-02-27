#define LUA_LIB
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include <string.h>
#include <stdio.h>

static int DEBUG_HOST = 0;	// host L in client VM
static int DEBUG_HOST_CONTEXT = 0;	// host L in client/debugger VM (original)
static int DEBUG_CLIENT = 0;	// client L in host VM for hook

static int DEBUG_HOOK = 0;	// hook function in client VM (void * in host VM)

int eval_value(lua_State *L, lua_State *cL);
void probe(lua_State* cL, lua_State* hL, const char* name);

static void
clear_client(lua_State *L) {
	lua_pushnil(L);
	lua_rawsetp(L, LUA_REGISTRYINDEX, &DEBUG_HOOK);	// clear hook

	lua_State *cL = NULL;
	if (lua_rawgetp(L, LUA_REGISTRYINDEX, &DEBUG_CLIENT) != LUA_TNIL) {
		cL = lua_touserdata(L, -1);
	}
	lua_pop(L, 1);
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

static void
copy_string(lua_State *L, lua_State *cL, const char * key) {
	if (lua_getfield(L, -1, key) != LUA_TSTRING)
		luaL_error(L, "Invalid string : package.%s", key);
	const char * s = lua_tostring(L, -1);
	lua_pushstring(cL, s);
	lua_setfield(cL, -2, key);
	lua_pop(L, 1);
}

static void
copy_package_path(lua_State *hL, lua_State *L) {
	if (lua_getglobal(hL, "package") != LUA_TTABLE)
		luaL_error(L, "No package");
	if (lua_getglobal(L, "package") != LUA_TTABLE)
		luaL_error(L, "No package in debugger VM");

	copy_string(hL, L, "path");
	copy_string(hL, L, "cpath");

	lua_pop(L, 1);
	lua_pop(hL, 1);
}

// 1. lightuserdata string_mainscript
// 2. lightuserdata host_L
static int
client_main(lua_State *L) {
	lua_State *hL = lua_touserdata(L, 2);
	luaL_openlibs(L);
	copy_package_path(hL, L);

	lua_pushvalue(L, 2);
	lua_rawsetp(L, LUA_REGISTRYINDEX, &DEBUG_HOST);	// set host L

	const char * mainscript = (const char *)lua_touserdata(L, 1);


	if (luaL_loadstring(L, mainscript) != LUA_OK) {
		return lua_error(L);
	}
	lua_pushvalue(L, 3);	// preprocessor
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
	const char * mainscript = luaL_checkstring(L, 1);	// index 1 is source
	if (lua_type(L, 2) == LUA_TFUNCTION) {
		// preprocess c function
		preprocessor = lua_tocfunction(L, 2);
		if (preprocessor == NULL) {
			return luaL_error(L, "Preprocessor must be a C function");
		}
		if (lua_getupvalue(L, 2, 1)) {
			return luaL_error(L, "Preprocessor must be a light C function (no upvalue)");
		}
	}
	lua_State *cL = luaL_newstate();
	if (cL == NULL)
		return luaL_error(L, "Can't new debug client");

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
	// register hook thread into host
	if (lua_checkstack(cL, 1) == 0) {
		clear_client(L);
		return luaL_error(L, "debugger L stack overflow");
	}
	if (lua_rawgetp(cL, LUA_REGISTRYINDEX, &DEBUG_HOOK) != LUA_TTHREAD) {
		clear_client(L);
		return luaL_error(L, "debugger has not set hook");
	}
	void * hook = lua_tothread(cL, -1);
	lua_pop(cL, 1);
	lua_pushlightuserdata(L, hook);
	lua_rawsetp(L, LUA_REGISTRYINDEX, &DEBUG_HOOK);
	return 0;
}

// use as hard break point
static int
lhost_probe(lua_State *L) {
	if (lua_rawgetp(L, LUA_REGISTRYINDEX, &DEBUG_HOOK) != LUA_TLIGHTUSERDATA) {
		// debugger not start
		return 0;
	}
	lua_State *cL = lua_touserdata(L, -1);
	probe(cL, L, luaL_checkstring(L, 1));
	return 0;
}

static int
call_debugger_hook(lua_State *L) {
	lua_State *cL = lua_touserdata(L, 1);
	lua_pushinteger(cL, lua_tointeger(L, 2));
	if (lua_type(L, 3) == LUA_TNUMBER) {
		lua_pushinteger(cL, lua_tointeger(L, 3));
	} else {
		lua_Debug ar;
		if (lua_getstack(L, 1, &ar) == 0 || lua_getinfo(L, "l", &ar) == 0) {
			return luaL_error(L, "can't get current line");
		}
		lua_pushinteger(cL, ar.currentline);
	}
	lua_pushlightuserdata(cL, L);
	if (lua_resume(cL, NULL, 3) == LUA_YIELD) {
		return 0;
	}
	return luaL_error(L, "debugger error: %s", lua_tostring(cL, -1));
}

static void
host_hook(lua_State *L, lua_Debug *ar) {
	if (lua_rawgetp(L, LUA_REGISTRYINDEX, &DEBUG_HOOK) != LUA_TLIGHTUSERDATA) {
		lua_sethook(L, NULL, 0, 0);
		return;
		// debugger not start
	}
	lua_State *cL = lua_touserdata(L, -1);
	lua_pushcfunction(L, call_debugger_hook);
	lua_pushlightuserdata(L, cL);
	lua_pushinteger(L, ar->event);
	if (ar->event != LUA_HOOKLINE) {
		lua_pushnil(L);
	} else {
		lua_pushinteger(L, ar->currentline);
	}
	if (lua_pcall(L, 3, 0, 0) != LUA_OK) {
		// todo: raise error message, remove this printf
		printf("hook err: %s\n", lua_tostring(L, -1));
		clear_client(L);
		lua_sethook(L, NULL, 0, 0);
	}
}

lua_State *
get_host(lua_State *L) {
	if (lua_rawgetp(L, LUA_REGISTRYINDEX, &DEBUG_HOST) != LUA_TLIGHTUSERDATA) {
		luaL_error(L, "Must call in debug client");
	}
	lua_State *hL = lua_touserdata(L, -1);
	lua_pop(L, 1);
	return hL;
}

void
set_host(lua_State* L, lua_State* hL) {
    lua_pushlightuserdata(L, hL);
    lua_rawsetp(L, LUA_REGISTRYINDEX, &DEBUG_HOST);
}

static int hook_loop_k(lua_State *L, int status, lua_KContext ctx);

static int
hook_again_k(lua_State *L, int status, lua_KContext ctx) {
	return lua_yieldk(L, 0, 0, hook_loop_k);	// resume hook_loop_k again
}

static int
hook_loop_k(lua_State *L, int status, lua_KContext ctx) {
	int currentline = lua_tointeger(L,2);
	lua_rawsetp(L, LUA_REGISTRYINDEX, &DEBUG_HOST);	// set host L
	lua_settop(L, 1);
	switch (lua_type(L, 1)) {
	case LUA_TNUMBER:
		switch(lua_tointeger(L, 1)) {
			case LUA_HOOKCALL:
				lua_pushstring(L, "call");
				break;
			case LUA_HOOKRET:
				lua_pushstring(L, "return");
				break;
			case LUA_HOOKLINE:
				lua_pushstring(L, "line");
				break;
			case LUA_HOOKCOUNT:
				lua_pushstring(L, "count");
				break;
			case LUA_HOOKTAILCALL:
				lua_pushstring(L, "tail call");
				break;
			default:
				return luaL_error(L, "Unkown hook event %d", (int)lua_tointeger(L, 1));
		}
		break;
	case LUA_TLIGHTUSERDATA:	// string
		lua_pushstring(L, (const char *)lua_touserdata(L, 1));
		break;
	default:
		lua_pushnil(L);
		break;
	}
	lua_pushvalue(L, lua_upvalueindex(1));
	lua_replace(L, 1);
	lua_pushinteger(L, currentline);
	lua_callk(L, 2, 0, 0, hook_again_k);
	return hook_again_k(L, 0, 0);
}

static int
hook_loop(lua_State *L) {
	hook_loop_k(L, 0, 0);
	return 0;
}

static int
lclient_switch(lua_State *L) {
	struct lua_State *hL = get_host(L);
	lua_settop(L, 1);
	if (lua_rawgetp(L, LUA_REGISTRYINDEX, &DEBUG_HOST_CONTEXT) == LUA_TNIL) {
		lua_pop(L, 1);
		lua_pushlightuserdata(L, (void *)hL);
		lua_rawsetp(L, LUA_REGISTRYINDEX, &DEBUG_HOST_CONTEXT);
		if (lua_isnil(L, 1)) {
			return 0;
		}
	} else {
		if (lua_isnil(L, 1)) {
			lua_rawsetp(L, LUA_REGISTRYINDEX, &DEBUG_HOST);
			return 0;
		} else {
			lua_pop(L, 1);
		}
	}
	luaL_checktype(L, 1, LUA_TUSERDATA);
	int ct = eval_value(L, hL);
	if (ct == LUA_TNONE) {
		return luaL_error(L, "Invalid thread");
	}
	if (ct != LUA_TTHREAD) {
		lua_pop(hL, 1);
		return luaL_error(L, "Need coroutine, Is %s", lua_typename(hL, ct));
	}
	lua_State *co = lua_tothread(hL, -1);
	lua_pop(hL, 1);
	lua_pushlightuserdata(L, (void *)co);
	lua_rawsetp(L, LUA_REGISTRYINDEX, &DEBUG_HOST);
	return 0;
}

static int
lclient_context(lua_State *L) {
	lua_rawgetp(L, LUA_REGISTRYINDEX, &DEBUG_HOST);
	lua_pushfstring(L, "[thread: %p]", lua_topointer(L, -1));
	return 1;
}

static int
lclient_sethook(lua_State *L) {
	luaL_checktype(L,1,LUA_TFUNCTION);
	lua_State *cL = lua_newthread(L);
	lua_pushvalue(L, 1);
	lua_pushcclosure(L, hook_loop, 1);
	lua_xmove(L, cL, 1);
	lua_rawsetp(L, LUA_REGISTRYINDEX, &DEBUG_HOOK);
	return 0;
}

static int
lclient_hookmask(lua_State *L) {
	lua_State *hL = get_host(L);
	int t = lua_type(L,1);
	int mask_index = 1;
	if (t == LUA_TUSERDATA) {
		lua_pushvalue(L, 1);
		int ct = eval_value(L, hL);
		lua_pop(L, 1);
		if (ct == LUA_TNONE) {
			return luaL_error(L, "Invalid thread");
		}
		if (ct != LUA_TTHREAD) {
			lua_pop(hL, 1);
			return luaL_error(L, "Need coroutine, Is %s", lua_typename(hL, ct));
		}
		lua_State *co = lua_tothread(hL, -1);
		lua_pop(hL, 1);
		hL = co;
		mask_index = 2;
	} 
	
	if (lua_type(L, mask_index) != LUA_TSTRING) {
		lua_sethook(hL, NULL, 0 , 0);
		return 0;
	}
	const char * mask = lua_tostring(L, mask_index);
	int m = 0, count = 0;
	int i;
	for (i=0;mask[i];i++) {
		switch (mask[i]) {
		case 'c':
			m |= LUA_MASKCALL;
			break;
		case 'r':
			m |= LUA_MASKRET;
			break;
		case 'l':
			m |= LUA_MASKLINE;
			break;
		}
	}
	if (lua_isinteger(L, mask_index+1)) {
		m |= LUA_MASKCOUNT;
		count = lua_tointeger(L, mask_index+1);
	}
	lua_sethook(hL, host_hook, m, count);
	return 0;
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

LUAMOD_API int
luaopen_remotedebug(lua_State *L) {
	luaL_checkversion(L);
	if (lua_rawgetp(L, LUA_REGISTRYINDEX, &DEBUG_HOST) != LUA_TNIL) {
		// It's client
		luaL_Reg l[] = {
			{ "switch", lclient_switch },
			{ "context", lclient_context },
			{ "sethook", lclient_sethook },
			{ "hookmask", lclient_hookmask },
			{ NULL, NULL },
		};
		luaL_newlib(L,l);
		lua_pushstring(L, "debugger");
		lua_setfield(L, -2, "status");
	} else {
		// It's host
		luaL_Reg l[] = {
			{ "start", lhost_start },
			{ "clear", lhost_clear },
			{ "probe", lhost_probe },
			{ NULL, NULL },
		};
		luaL_newlib(L,l);
		lua_pushstring(L, "host");
		lua_setfield(L, -2, "status");

		// autoclose debugger VM, __gc in module table
		lua_createtable(L,0,1);
		lua_pushcfunction(L, lhost_clear);
		lua_setfield(L, -2, "__gc");
		lua_setmetatable(L, -2);
	}
	return 1;
}
