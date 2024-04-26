local lm = require "luamake"

lm:lua_src "protocol" {
    sources = {
        "lprotocol.c",
    }
}
