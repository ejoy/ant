local lm = require "luamake"
local ROOT <const> = "../../"

lm:lua_source "motion_sampler" {
    deps = {
        "ozz-animation-runtime",
    },
    includes = {
        ROOT .. "3rd/math3d",
        --ROOT .. "3rd/glm",
        ROOT .. "3rd/luaecs",
        ROOT .. "3rd/ozz-animation/include",
        ROOT .. "clibs/ecs",
    },
    sources = {
        "tween.cpp",
        "motion_sampler.cpp",
    },
    objdeps = "compile_ecs",
}