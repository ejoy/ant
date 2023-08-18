local lm = require "luamake"
local ROOT <const> = "../../"

lm:lua_source "material_core"{
    includes = {
        ROOT .. "3rd/bgfx/include",
        ROOT .. "3rd/bx/include",
        ROOT .. "3rd/math3d",
        ROOT .. "clibs/bgfx",
        ROOT .. "clibs/ecs",
        ROOT .. "pkg/ant.bundle/src",
    },
    sources = {
        "material_arena.c",
        "material.c",
        "render_material.c",
    },
}