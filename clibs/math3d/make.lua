local lm = require "luamake"

lm:lua_dll "math3d" {
    sources = {
        "linalg.c",
        "math3d.c",
        "math3dfunc.cpp",
        "mathadapter.c",
        "testadapter.c",
    },
    includes = {
        "../../3rd/glm",
    },
    defines = {
        "LUA_BUILD_AS_DLL",
        "_USE_MATH_DEFINES",
    },
    ldflags = {
        lm.plat == "msvc" and "-export:luaopen_math3d_adapter",
        lm.plat == "msvc" and "-export:luaopen_math3d_adapter_test",
    }
}