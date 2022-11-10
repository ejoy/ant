local lm = require "luamake"

dofile "../common.lua"

local LuaInclude <const> = Ant3rd .. "bee.lua/3rd/lua/"

lm:lua_source "remotedebug" {
    cxx = "c++17", --TODO: clang does not support c++20
    includes = {
        LuaInclude,
        Ant3rd .. "bee.lua/",
        Ant3rd .. "bee.lua/3rd/lua-seri",
    },
    defines = {
        "RLUA_DISABLE",
        "LUA_DLL_VERSION=lua54"
    },
    sources = {
        "*.cpp",
        "!bee_inline.cpp",
        "thunk/*.cpp",
    },
    windows = {
        links = "user32"
    }
}
