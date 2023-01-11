local lm = require "luamake"
local ROOT <const> = "../../"

lm:lua_source "motion_sampler" {
    includes = {
        ROOT .. "3rd/math3d",
        --ROOT .. "3rd/glm",
        ROOT .. "3rd/luaecs",
        ROOT .. "clibs/ecs",
    },
    sources = {
        "motion_sampler.cpp",
    },
    objdeps = "compile_ecs",
}