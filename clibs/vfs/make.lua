local lm = require "luamake"

dofile "../common.lua"

lm:source_set "source_vfs" {
    includes = LuaInclude,
    sources = {
        "vfs.cpp",
    }
}

lm:lua_dll "vfs" {
    deps = "source_vfs"
}
