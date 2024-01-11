#include "ecs/component.hpp"
#include <lua.hpp>

template <size_t I = 0>
static void push_component_name(lua_State* L) {
    if constexpr (I < std::tuple_size_v<component::_all_>) {
        constexpr auto name = ecs::helper::component_name_v<std::tuple_element_t<I, component::_all_>>;
        lua_pushlstring(L, name.data(), name.size());
        lua_pushinteger(L, (lua_Integer)I+1);
        lua_rawset(L, -3);
        push_component_name<I+1>(L);
    }
}

extern "C" int
luaopen_ecs_components(lua_State* L) {
    lua_createtable(L, 0, (int)std::tuple_size_v<component::_all_>);
    push_component_name(L);
    return 1;
}
