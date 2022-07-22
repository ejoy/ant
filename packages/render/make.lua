local lm = require "luamake"

lm:lua_source "render_core"{
    includes = {
        "../../3rd/bgfx/include",
        "../../3rd/bx/include",
        "../../clibs/bgfx",
        "../../clibs/lua",
        "../../clibs/math3d",
        "../../clibs/foundation",
        "../../clibs/luabind",
        "../../3rd/glm",
        "../../3rd/luaecs",
        "../../clibs/ecs",
    },
    defines = {
        "GLM_FORCE_QUAT_DATA_XYZW",
    },
    sources = {
        "render/material.c",
        "render/mesh.cpp",
        "render/render.cpp",
    }
}

lm:lua_source "render" {
    includes = {
        "../../clibs/lua",
        "../../clibs/math3d",
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