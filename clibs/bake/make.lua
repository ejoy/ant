local lm = require "luamake"

dofile "../common.lua"

lm:source_set "source_bake" {
    includes = {LuaInclude, BgfxInclude},
    sources = {
        "lightmapping.cpp",
    }
}

lm:lua_dll "bake" {
    deps = "source_bake"
}
