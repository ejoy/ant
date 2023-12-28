#include "ecs/component.hpp"
#include <lua.hpp>

extern "C" int
luaopen_ecs_components(lua_State *L) {
    const auto& components = component::decl::components;
    lua_createtable(L, 0, (int)components.size());
    for (size_t i = 0; i < components.size(); ++i) {
        lua_pushlstring(L, components[i].name.data(), components[i].name.size());
        lua_pushinteger(L, (lua_Integer)i+1);
        lua_rawset(L, -3);
    }
    return 1;
}
