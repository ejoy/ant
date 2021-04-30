local lm = require "luamake"

dofile "../common.lua"

lm:source_set "source_remotedebug" {
    includes = LuaInclude,
    defines = {
        "RLUA_DISABLE"
    },
    sources = {
        "*.cpp",
    },
    windows = {
        links = "user32"
    }
}

lm:lua_dll "remotedebug" {
    deps = "source_remotedebug"
}
