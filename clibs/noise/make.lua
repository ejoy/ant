local lm = require "luamake"

dofile "../common.lua"

lm:lua_source "noise" {
    includes = {
        Ant3rd .. "glm"
    },
    sources = {
        "noise.cpp",
    },
}
