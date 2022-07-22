local lm = require "luamake"

dofile "../common.lua"

lm:lua_source "math3d" {
    includes = {
        Ant3rd .. "glm",
        Ant3rd .. "math3d",
    },
    sources = {
        Ant3rd .. "math3d/mathid.c",
        Ant3rd .. "math3d/math3d.c",
        Ant3rd .. "math3d/math3dfunc.cpp",
        Ant3rd .. "math3d/mathadapter.c",
        Ant3rd .. "math3d/testadapter.c",
    },
    defines = {
        "_USE_MATH_DEFINES",
        "GLM_FORCE_QUAT_DATA_XYZW",
    }
}
