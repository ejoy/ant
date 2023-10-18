local lm = require "luamake"

local ROOT <const> = "../../"

lm:lua_source "math" {
    includes = {
        ROOT .. "3rd/glm",
        ROOT .. "3rd/math3d",
    },
    sources = {
        ROOT .. "3rd/math3d/mathid.c",
        ROOT .. "3rd/math3d/math3d.c",
        ROOT .. "3rd/math3d/math3dfunc.cpp",
        ROOT .. "3rd/math3d/mathadapter.c",
        ROOT .. "3rd/math3d/testadapter.c",
    },
    defines = {
        "_USE_MATH_DEFINES",
        "GLM_FORCE_QUAT_DATA_XYZW",
    }
}
