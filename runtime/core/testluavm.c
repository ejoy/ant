#include "luavm.h"
#include <stdio.h>
#include <lua.h>
#include <lauxlib.h>
#include <string.h>

static int
lerror(lua_State *L) {
	lua_settop(L, 1);
	return lua_error(L);
}

static int
luaopen_util(lua_State *L) {
	luaL_Reg l[] = {
		{ "error", lerror },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}

static const luaL_Reg preload[] = {
	{ "util", luaopen_util },
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

int
main() {
	struct luavm *V = luavm_new();
	const char *err = luavm_init(V, 
		"local log, preload_searcher = ... " "\n"
		"_ERR = log" "\n"
		"package.searchers[3] = preload_searcher" "\n"
		, "f", preload_searcher);

	if (err) {
		printf("init error : %s\n", err);
		return 1;
	}
	int handle;
	err = luavm_register(V, 
		"return function(...)" "\n"
		"	print (...)" "\n"
		"	return select ('#',...)" "\n"
		"end" "\n"
		, "=print", &handle);
	if (err) {
		printf("Register error : %s\n", err);
		return 1;
	}
	printf("Register print to %d\n", handle);

	int printerr;
	
	err = luavm_register(V,
		"local err = _ERR" "\n"
		"return function()" "\n"
		"	for i,msg in ipairs(err) do" "\n"
		"		print(i, msg)" "\n"
		"		err[i] = nil" "\n"
		"	end" "\n"
		"end" "\n"
		, "=printerr", &printerr);
	if (err) {
		printf("Register error : %s\n", err);
		return 1;
	}

	printf("Register printerr to %d\n", printerr);

	int error;

	err = luavm_register(V,
		"local util = require 'util'" "\n"
		"return function(msg)" "\n"
		"	util.error(msg)" "\n"
		"end" "\n"
		, "=error", &error);
	if (err) {
		printf("Register error : %s\n", err);
		return 1;
	}

	printf("Register error to %d\n", error);

	int ret = 0;
	if (luavm_call(V, handle, "Isnib", &ret, "Hello", 1.0,2,0) == NULL) {
		printf("ret = %d\n", ret);
	}
	luavm_call(V, error, "s", "error test");

	err = luavm_call(V, printerr, NULL);
	if (err) {
		printf("Error on printerr (%d): %s\n", printerr, err);
	}
	luavm_close(V);
	return 0;
}
