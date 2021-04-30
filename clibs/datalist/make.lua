local lm = require "luamake"

dofile "../common.lua"

lm:source_set "source_datalist" {
    includes = LuaInclude,
    sources = {
        "datalist.c",
    }
}

lm:lua_dll "datalist" {
    deps = "source_datalist"
}
