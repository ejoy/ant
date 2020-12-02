#include "pch.h"
#include "file.h"
#include "luabind.h"

#if defined(_WIN32)
#include <Windows.h>

std::wstring u2w(const std::string_view& str) {
    if (str.empty()) {
        return L"";
    }
    int wlen = ::MultiByteToWideChar(CP_UTF8, 0, str.data(), (int)str.size(), NULL, 0);
    if (wlen <= 0) {
        return L"";
    }
    std::vector<wchar_t> result(wlen);
    ::MultiByteToWideChar(CP_UTF8, 0, str.data(), (int)str.size(), result.data(), (int)wlen);
    return std::wstring(result.data(), result.size());
}
#endif

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
#if defined(_WIN32)
    return (Rml::FileHandle)_wfopen(u2w(result).c_str(), L"rb");
#else
    return (Rml::FileHandle)fopen(result.c_str(), "rb");
#endif
}
