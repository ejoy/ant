local lm = require "luamake"

lm:lua_src "foundation" {
    sources = {
        "vla.c",
        "set.c"
    }
}