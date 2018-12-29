#include <lua.hpp>
#include "binding.h"
#include "span.h"
#include "incbin.h"
#define define_embed(NAME, FILENAME) INCBIN(NAME, FILENAME)
#define embed(NAME, FILENAME) nonstd::span<const std::byte>((const std::byte*)g##NAME##Data, (size_t)g##NAME##Size)

static int do_span(lua_State* L, const char* name, const nonstd::span<const std::byte>& span) {
    if (luaL_loadbuffer(L, (const char*)span.data(), span.size() - 1, name) != LUA_OK) {
        return lua_error(L);
    }
    lua_call(L, 0, 1);
    return 1;
}

#if defined(__MINGW32__)
define_embed(mingw_patch, "mingw_patch.lua");

ANT_LUA_API
int luaopen_filesystem(lua_State* L) {
    return do_span(L, "=module 'filesystem::mingw_patch'", embed(mingw_patch, "mingw_patch.lua"));
}

#elif defined(__APPLE__)
define_embed(macos_patch, "macos_patch.lua");

ANT_LUA_API
int luaopen_filesystem(lua_State* L) {
    return do_span(L, "=module 'filesystem::macos_patch'", embed(macos_patch, "macos_patch.lua"));
}
#else
int luaopen_filesystem_cpp(lua_State* L);

ANT_LUA_API
int luaopen_filesystem(lua_State* L) {
	if (luaL_loadstring(L, "return require 'filesystem.cpp'") || lua_pcall(L, 0, 1, 0)) {
        return lua_error(L);
    }
    return 1;
}
#endif
