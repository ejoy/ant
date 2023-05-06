#include <lua.hpp>

int ldpi(lua_State* L) {
    //TODO
    lua_pushinteger(L, 1);
    lua_pushinteger(L, 1);
    return 2;
}

int linfo(lua_State* L) {
    const char* lst[] = {"memory", NULL};
    int opt = luaL_checkoption(L, 1, NULL, lst);
    switch (opt) {
    case 0: {
        //TODO
        lua_pushinteger(L, 0);
        return 1;
    }
    default:
        return luaL_error(L, "invalid option");
    }
}
