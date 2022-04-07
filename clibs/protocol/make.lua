local lm = require "luamake"

lm:lua_source "protocol" {
    sources = {
        "lprotocol.c",
    }
}
