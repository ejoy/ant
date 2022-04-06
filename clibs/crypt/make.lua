local lm = require "luamake"

lm:lua_source "crypt" {
    sources = {
        "lsha1.c",
        "lua-crypt.c"
    }
}
