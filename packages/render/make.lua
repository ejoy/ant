local lm = require "luamake"

lm:lua_source "render" {
    includes = {
        "../../3rd/bgfx/include",
        "../../3rd/bx/include",
        "../../clibs/bgfx",
        "../../clibs/lua",
        "../../clibs/math3d",
        "../../clibs/foundation",
        "../../clibs/luabind",
        "../../3rd/luaecs",
        "../../clibs/ecs",
    },
    sources = {
        "material/material.c",
        "mesh.cpp",
        "cull.cpp",
        "render.cpp",
    },
}