#include "luavm.h"
#include <stdio.h>
#include <lua.h>
#include <lauxlib.h>
#include <string.h>

// A util function to return an integer
static int
lset(lua_State *L) {
	luaL_checktype(L, 1, LUA_TLIGHTUSERDATA);
	int *p = (int *)lua_touserdata(L, 1);
	int a = luaL_checkinteger(L, 2);
	*p = a;
	return 0;
}

static int
luaopen_set(lua_State *L) {
	lua_pushcfunction(L, lset);
	return 1;
}

static const luaL_Reg preload[] = {
	{ "set", luaopen_set },
	{ NULL, NULL },
};

static int
preload_searcher(lua_State *L) {
	const char * modname = luaL_checkstring(L,1);
	int i;
	for (i=0;preload[i].name != NULL;i++) {
		if (strcmp(modname, preload[i].name) == 0) {
			lua_pushcfunction(L, preload[i].func);
			return 1;
		}
	}
	lua_pushfstring(L, "\n\tno preload C module '%s'", modname);
	return 1;
}

static void
err(struct luavm *V) {
	printf("%s\n", luavm_lasterror(V));
}

int
main() {
	struct luavm *V = luavm_new();
	if (luavm_init(V, 
		"local log, preload_searcher = ... " "\n"
		"_ERR = log" "\n"
		"package.searchers[3] = preload_searcher" "\n"
		, "f", preload_searcher)) {
		err(V);
	}
	int handle = luavm_register(V, 
		"local set = require 'set'" "\n"
		"return function(ret, ...)" "\n"
		"	set(ret, 100)" "\n"
		"	print (...)" "\n"
		"	error 'ERR'" "\n"
		"end" "\n"
		, "=print");
	if (handle == 0) {
		err(V);
	}
	int printerr = luavm_register(V,
		"local err = _ERR" "\n"
		"return function()" "\n"
		"	for i,err in ipairs(err) do" "\n"
		"		print(i, err)" "\n"
		"		err[i] = nil" "\n"
		"	end" "\n"
		"end" "\n"
		, "=printerr");
	if (printerr == 0) {
		err(V);
	}
	int ret = 0;
	if (luavm_call(V, handle, "psnib", &ret, "Hello", 1.0,2,0)) {
		luavm_call(V, printerr, NULL);
	}
	printf("ret = %d\n", ret);
	luavm_close(V);
	return 0;
}
