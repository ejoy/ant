#include <lua.hpp>
#include "filewatch.h"

struct strview {
    template <class T>
    strview(const T& str)
        : buf(str.data())
        , len(str.size())
    { }
    strview(const char* buf, size_t len)
        : buf(buf)
        , len(len)
    { }
    strview(const char* buf)
        : buf(buf)
        , len(strlen(buf))
    { }
    bool empty() const { return buf == 0; }
    const char* data() const { return buf; }
    size_t size() const { return len; }
    const char* buf;
    size_t len;
};

struct wstrview {
    template <class T>
    wstrview(const T& str)
        : buf(str.data())
        , len(str.size())
    { }
    wstrview(const wchar_t* buf, size_t len)
        : buf(buf)
        , len(len)
    { }
    bool empty() const { return buf == 0; }
    const wchar_t* data() const { return buf; }
    size_t size() const { return len; }
    const wchar_t* buf;
    size_t len;
};

static std::wstring u2w(const strview& str) {
    if (str.empty()) {
        return L"";
    }
    int wlen = ::MultiByteToWideChar(CP_UTF8, 0, str.data(), (int)str.size(), NULL, 0);
    if (wlen <= 0) {
        return L"";
    }
    std::vector<wchar_t> result(wlen);
    ::MultiByteToWideChar(CP_UTF8, 0, str.data(), (int)str.size(), result.data(), wlen);
    return std::wstring(result.data(), result.size());
}

static std::string w2u(const wstrview& wstr) {
    if (wstr.empty()) {
        return "";
    }
    int len = ::WideCharToMultiByte(CP_UTF8, 0, wstr.data(), (int)wstr.size(), NULL, 0, 0, 0);
    if (len <= 0) {
        return "";
    }
    std::vector<char> result(len);
    ::WideCharToMultiByte(CP_UTF8, 0, wstr.data(), (int)wstr.size(), result.data(), len, 0, 0);
    return std::string(result.data(), result.size());
}

static int fw_add(lua_State* L) {
    size_t pathlen = 0;
    const char* path = luaL_checklstring(L, 1, &pathlen);
    int filter = 0;
    const char* sf = luaL_checkstring(L, 2);
    for (const char* f = sf; *f; ++f) {
        switch (*f) {
        case 'f': filter |= FileWatch::FilterFile; break;
        case 'd': filter |= FileWatch::FilterDir; break;
        case 't': filter |= FileWatch::FilterTime; break;
        case 's': filter |= FileWatch::FilterSubtree; break;
        }
    }
    FileWatch& self = *(FileWatch*)lua_touserdata(L, lua_upvalueindex(1));
    FileWatch::TaskId id = self.add(u2w(strview(path, pathlen)), filter);
    if (id == FileWatch::kInvalidTaskId) {
        lua_pushnil(L);
        lua_pushfstring(L, "Add watch failed. Error = %d.", ::GetLastError());
        return 2;
    }
    lua_pushinteger(L, id);
    return 1;
}

static int fw_remove(lua_State* L) {
    FileWatch& self = *(FileWatch*)lua_touserdata(L, lua_upvalueindex(1));
    self.remove((FileWatch::TaskId)luaL_checkinteger(L, 1));
    return 0;
}

static int fw_select(lua_State* L) {
    FileWatch& self = *(FileWatch*)lua_touserdata(L, lua_upvalueindex(1));
    FileWatch::Notify notify;
    if (self.pop(notify)) {
        lua_pushinteger(L, notify.id);
        switch (notify.type) {
        case FileWatch::Notify::Type::Create:
            lua_pushstring(L, "create");
            break;
        case FileWatch::Notify::Type::Delete:
            lua_pushstring(L, "delete");
            break;
        case FileWatch::Notify::Type::Modify:
            lua_pushstring(L, "modify");
            break;
        case FileWatch::Notify::Type::RenameFrom:
            lua_pushstring(L, "rename from");
            break;
        case FileWatch::Notify::Type::RenameTo:
            lua_pushstring(L, "rename to");
            break;
        default:
            lua_pushstring(L, "unknown");
            break;
        }
        std::string upath = w2u(notify.path);
        lua_pushlstring(L, upath.data(), upath.size());
        return 3;
    }
    return 0;
}

static int fw_gc(lua_State* L) {
    FileWatch& self = *(FileWatch*)lua_touserdata(L, lua_upvalueindex(1));
    self.~FileWatch();
    return 0;
}

extern "C"
#if defined(_WIN32)
__declspec(dllexport)
#endif
int luaopen_filewatch(lua_State* L) {
    FileWatch* fw = (FileWatch*)lua_newuserdata(L, sizeof(FileWatch));
    new (fw)FileWatch;

    static luaL_Reg lib[] = {
        { "add",    fw_add },
        { "remove", fw_remove },
        { "select", fw_select },
        { "__gc",   fw_gc },
        { NULL, NULL }
    };
    lua_newtable(L);
    lua_pushvalue(L, -2);
    luaL_setfuncs(L, lib, 1);
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");
    lua_setmetatable(L, -2);
    return 1;
}
