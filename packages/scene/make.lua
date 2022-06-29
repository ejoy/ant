local lm = require "luamake"

lm:lua_source "scene" {
    includes = {
        "../../clibs/lua",
        "../../clibs/math3d",
    },
    sources = {
        "scene.c"
    }
}