#include "pch.h"
#include "file.h"
#include "luabind.h"

Rml::FileHandle File::Open(const Rml::String& path){
    plugin_t plugin = mcontext->plugin;
    lua_State* L = lua_plugin_getlua(plugin);
    std::string result;
    luabind::invoke(L, [&](lua_State* L) {
        lua_pushlstring(L, path.data(), path.size());
        lua_plugin_call(plugin, "OnOpenFile", 1, 1);
        if (lua_type(L, -1) == LUA_TSTRING) {
            size_t sz = 0;
            const char* str = lua_tolstring(L, -1, &sz);
            result.assign(str, sz);
        }
    });
    return Rml::FileInterfaceDefault::Open(result);
}
