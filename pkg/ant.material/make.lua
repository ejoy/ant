local lm = require "luamake"

lm:lua_src "material_core"{
    includes = {
        lm.AntDir .. "/3rd/bgfx/include",
        lm.AntDir .. "/3rd/bx/include",
        lm.AntDir .. "/3rd/math3d",
        lm.AntDir .. "/clibs/bgfx",
        lm.AntDir .. "/clibs/ecs",
        lm.AntDir .. "/pkg/ant.resource_manager/src",
    },
    defines = {
        "MATERIAL_DEBUG=0"
    },
    sources = {
        "material_arena.c",
        "material.c",
        "render_material.c",
    },
}