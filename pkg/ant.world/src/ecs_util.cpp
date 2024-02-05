#include <lua.hpp>
#include <string.h>

static int userdata(lua_State* L) {
    lua_settop(L, 2);
    size_t size = 0;
    const char* data = luaL_checklstring(L, 1, &size);
    void* ud = lua_newuserdatauv(L, size, 1);
    memcpy(ud, data, size);
    lua_pushvalue(L, 2);
    lua_setiuservalue(L, -2, 1);
    return 1;
}

extern "C" int
luaopen_ecs_util(lua_State* L) {
	luaL_checkversion(L);
	luaL_Reg l[] = {
		{ "userdata", userdata },
		{ NULL, NULL },
	};
	luaL_newlib(L, l);
	return 1;
}
