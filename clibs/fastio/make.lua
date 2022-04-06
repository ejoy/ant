local lm = require "luamake"

lm:lua_source "fastio" {
    sources = {
        "fastio.cpp",
    },
}
