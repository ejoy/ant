local lm = require "luamake"

lm:lua_source "fastio" {
    includes = {
        lm.AntDir .. "/clibs/foundation",
        lm.AntDir .. "/3rd/bee.lua",
    },
    sources = {
        "fastio.cpp",
        "sha1.c",
    },
}
