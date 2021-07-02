local lm = require "luamake"

dofile "../common.lua"

lm:source_set "source_fastio" {
    includes = {
        LuaInclude,
    },
    sources = {
        "fastio.cpp",
    },
}

lm:lua_dll "fastio" {
    deps = "source_fastio",
}
