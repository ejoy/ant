#define LUA_LIB 1
#include <lua.hpp>

extern "C"{
    #include "cubesphere.h"
}

union trunkid{
    int id;
    struct {
        int x : 14;
        int y : 14;
        int face : 4;
    };
};

trunkid to_trunkid(int id, int n){
    struct cubesphere_coord c;
    cubesphere_coord(n, id, &c);
    trunkid tid;
    tid.face = c.faceid;
    tid.x = c.x;
    tid.y = c.y;
    return tid;
}

int to_id(trunkid id, int n){
    return id.face * n * n + id.y * n + id.x;
}

int lneighbor(lua_State *L){
    const trunkid id = {int(luaL_checkinteger(L, 1))};
    const int num = luaL_checkinteger(L, 2);

    int out_ids[4];
    cubesphere_neighbor(num, to_id(id, num), out_ids);
    lua_createtable(L, 4, 0);
    for (int ii=0; ii<4; ++ii){
        lua_pushinteger(L, to_trunkid(out_ids[ii], num).id);
        lua_seti(L, -2, ii+1);
    }
    return 1;
}

extern "C"{
    LUAMOD_API int
    luaopen_quadsphere(lua_State* L) {
        luaL_Reg lib[] = {
            { "neighbor", lneighbor},
            { nullptr, nullptr },
        };
        luaL_newlib(L, lib);
        return 1;
    }
}