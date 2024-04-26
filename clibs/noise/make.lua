local lm = require "luamake"

lm:lua_src "noise" {
    confs = { "glm" },
    sources = {
        "noise.cpp",
    },
}
