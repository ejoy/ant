#include "ecs/component.hpp"
#include <lua.hpp>

extern "C" int
luaopen_ecs_components(lua_State *L) {
    const auto& components = ant::component_decls;
    lua_createtable(L, components.size(), components.size());
    for (size_t i = 0; i < components.size(); ++i) {
        lua_pushlstring(L, components[i].name.data(), components[i].name.size());
        if (components[i].size != 0) {
            lua_pushvalue(L, -1);
            lua_pushinteger(L, (lua_Integer)components[i].size);
            lua_rawset(L, -4);
        }
        lua_seti(L, -2, i+1);
    }
    return 1;
}
