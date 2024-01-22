local lm = require "luamake"

lm:lua_source "foundation" {
    sources = {
        "vla.c",
        "set.c"
    }
}