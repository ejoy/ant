local lm = require "luamake"

dofile "../common.lua"

lm:source_set "source_quadsphere" {
    includes = LuaInclude,
    sources = {
        "cubesphere.c",
        "quadsphere.cpp"
    }
}

lm:lua_dll "quadsphere" {
    deps = "source_quadsphere"
}
