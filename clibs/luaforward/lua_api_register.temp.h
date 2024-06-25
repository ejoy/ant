#ifndef LUA_API_REGISTER_H
#define LUA_API_REGISTER_H

#include <lua.h>
#include <lauxlib.h>

struct lua_api {
	int version;

	$API_DECL$
};

typedef const char * (*lua_api_register)(struct lua_api);

#endif
