local lm = require "luamake"

dofile "../common.lua"

lm:source_set "foundation" {
    includes = LuaInclude,
    sources = {
        "vla.c",
        "set.c"
    }
}