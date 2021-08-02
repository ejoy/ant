#include "pch.h"
#include "file.h"
#include "luabind.h"
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

std::string File::GetPath(const std::string& path) {
    lua_plugin* plugin = get_lua_plugin();
    std::string result;
    luabind::invoke([&](lua_State* L) {
        lua_pushlstring(L, path.data(), path.size());
        plugin->call(L, LuaEvent::OnOpenFile, 1, 1);
        if (lua_type(L, -1) == LUA_TSTRING) {
            size_t sz = 0;
            const char* str = lua_tolstring(L, -1, &sz);
            result.assign(str, sz);
        }
    });
    return result;
}

Rml::FileHandle File::Open(const std::string& path) {
    std::string result = GetPath(path);
#if defined(_WIN32)
    return (Rml::FileHandle)_wfopen(u2w(result).c_str(), L"rb");
#else
    return (Rml::FileHandle)fopen(result.c_str(), "rb");
#endif
}

void File::Close(Rml::FileHandle file) {
    fclose((FILE*)file);
}
size_t File::Read(void* buffer, size_t size, Rml::FileHandle file) {
    return fread(buffer, 1, size, (FILE*)file);
}
bool File::Seek(Rml::FileHandle file, long offset, int origin) {
    return fseek((FILE*)file, offset, origin) == 0;
}
size_t File::Tell(Rml::FileHandle file) {
    return ftell((FILE*)file);
}
