local lm = require "luamake"

lm:lua_source "noise" {
    confs = { "glm" },
    sources = {
        "noise.cpp",
    },
}
