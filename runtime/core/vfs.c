#include "luavm.h"
#include "vfs.h"
#include <lua.h>
#include <lauxlib.h>
#include <stdio.h>

struct vfs {
	struct luavm *L;
	int handle;
};

static int
linitvfs(lua_State *L) {
	luaL_checktype(L,1, LUA_TLIGHTUSERDATA);
	struct vfs ** V = (struct vfs **)lua_touserdata(L, 1);
	*V = lua_newuserdata(L, sizeof(struct vfs));
	return 1;
}

static int
lreturnstring(lua_State *L) {
	luaL_checktype(L,1, LUA_TLIGHTUSERDATA);
	const char ** r = (const char **)lua_touserdata(L, 1);
	*r = luaL_checkstring(L, 2);
	return 0;
}

static int
cfuncs(lua_State *L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "initvfs", linitvfs },
		{ "returnstring", lreturnstring },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}

static const char * init_source = "local _, firmware = ... ; loadfile(firmware .. '/bootstrap.lua')(...)";

struct vfs *
vfs_init(const char *firmware, const char *dir) {
	struct luavm *L = luavm_new();
	if (L == NULL)
		return NULL;
	struct vfs *V = NULL;
	if (luavm_init(L, init_source, "ssfp", firmware, dir, cfuncs, &V)) {
		fprintf(stderr, "Init error: %s\n", luavm_lasterror(L));
		luavm_close(L);
		return NULL;
	}
	if (V == NULL) {
		luavm_close(L);
		return NULL;
	}

	V->L = L;
	V->handle = luavm_register(L, "return _LOAD", "=vfs.load");
	if (V->handle == 0) {
		// register failed
		fprintf(stderr, "Register error: %s\n", luavm_lasterror(L));
		luavm_close(L);
		return NULL;
	}
	return V;
}

void
vfs_exit(struct vfs *V) {
	if (V) {
		luavm_close(V->L);
	}
}

const char *
vfs_load(struct vfs *V, const char *path) {
	const char * ret = NULL;
	if (luavm_call(V->L, V->handle, "sp", path, &ret)) {
		fprintf(stderr, "Load error: %s\n", luavm_lasterror(V->L));
		return NULL;
	}
	return ret;
}
