local lm = require "luamake"

dofile "../common.lua"

lm:lua_source "terrain" {
    includes = {
        Ant3rd .. "glm"
    },
    sources = {
        "terrain.cpp",
    },
    defines = {
        "GLM_FORCE_QUAT_DATA_XYZW",
    },
}
