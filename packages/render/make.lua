local lm = require "luamake"

lm:lua_source "render_core"{
    includes = {
        "../../3rd/bgfx/include",
        "../../3rd/bx/include",
        "../../clibs/bgfx",
        "../../3rd/bee.lua/3rd/lua",
        "../../3rd/math3d",
        "../../clibs/foundation",
        "../../clibs/luabind",
        "../../3rd/glm",
        "../../3rd/luaecs",
        "../../clibs/ecs",
        "../../packages/bundle/src",
    },
    defines = {
        "GLM_FORCE_QUAT_DATA_XYZW",
    },
    objdeps = "compile_ecs",
    sources = {
        "render/material.c",
        "render/render.cpp",
    }
}

lm:lua_source "render" {
    includes = {
        "../../3rd/bee.lua/3rd/lua",
        "../../3rd/math3d",
        "../../clibs/luabind",
        "../../3rd/luaecs",
        "../../3rd/glm",
        "../../clibs/ecs",
    },
    defines = {
        "GLM_FORCE_QUAT_DATA_XYZW",
    },
    sources = {
        "cull.cpp",
    },
    deps = "render_core",
}