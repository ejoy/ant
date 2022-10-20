local lm = require "luamake"

dofile "../common.lua"

lm:lua_source "foundation" {
    sources = {
        "vla.c",
        "set.c"
    }
}