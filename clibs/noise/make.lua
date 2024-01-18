local lm = require "luamake"

lm:lua_source "noise" {
    includes = {
        lm.AntDir .. "/3rd/glm"
    },
    sources = {
        "noise.cpp",
    },
}
