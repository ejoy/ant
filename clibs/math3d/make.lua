local lm = require "luamake"

dofile "../common.lua"

lm:source_set "source_math3d" {
    includes = {
        LuaInclude,
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

lm:lua_dll "math3d" {
    deps = "source_math3d",
    msvc = {
        ldflags = {
            "-export:luaopen_math3d_adapter",
            "-export:luaopen_math3d_adapter_test",
        }
    }
}
