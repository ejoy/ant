local lm = require "luamake"

dofile "../common.lua"

lm:lua_source "math3d" {
    includes = {
        Ant3rd .. "glm",
    },
    sources = {
        "linalg.c",
        "math3d.c",
        "math3dfunc.cpp",
        "mathadapter.c",
        "testadapter.c",
    },
    defines = {
        "_USE_MATH_DEFINES",
        "GLM_FORCE_QUAT_DATA_XYZW",
    }
}
