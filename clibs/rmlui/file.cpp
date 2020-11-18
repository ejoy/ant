#include "pch.h"
#include "file.h"
#include "luabind.h"

Rml::FileHandle File::Open(const Rml::String& path){
    lua_plugin* plugin = mcontext->plugin;
    lua_State* L = plugin->L;
    std::string result;
    luabind::invoke(L, [&]() {
        lua_pushlstring(L, path.data(), path.size());
        plugin->call(LuaEvent::OnOpenFile, 1, 1);
        if (lua_type(L, -1) == LUA_TSTRING) {
            size_t sz = 0;
            const char* str = lua_tolstring(L, -1, &sz);
            result.assign(str, sz);
        }
    });
    return Rml::FileInterfaceDefault::Open(result);
}
