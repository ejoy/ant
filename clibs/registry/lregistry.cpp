struct lua_State;

namespace bee::lua_registry {
    int luaopen(lua_State* L);
}

extern "C" __declspec(dllexport)
int luaopen_registry(lua_State* L) {
    return bee::lua_registry::luaopen(L);
}
