#include "ecs/component.hpp"
#include <lua.hpp>

template <size_t I = 0>
static void push_component_name(lua_State* L) {
    if constexpr (I < std::tuple_size_v<component::all_components>) {
        constexpr auto name = ecs::component_name_v<std::tuple_element_t<I, component::all_components>>;
        lua_pushlstring(L, name.data(), name.size());
        lua_pushinteger(L, (lua_Integer)I+1);
        lua_rawset(L, -3);
        push_component_name<I+1>(L);
    }
}

extern "C" int
luaopen_ecs_components(lua_State* L) {
    lua_createtable(L, 0, (int)std::tuple_size_v<component::all_components>);
    push_component_name(L);
    return 1;
}
