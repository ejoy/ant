local lm = require "luamake"

dofile "../common.lua"

local LuaInclude <const> = Ant3rd .. "bee.lua/3rd/lua/"

lm:lua_source "remotedebug" {
    cxx = "c++17", --TODO: clang does not support c++20
    includes = LuaInclude,
    defines = {
        "RLUA_DISABLE"
    },
    sources = {
        "*.cpp",
        "thunk/*.cpp",
    },
    windows = {
        links = "user32"
    }
}
