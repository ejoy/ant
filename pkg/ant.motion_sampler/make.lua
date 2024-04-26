local lm = require "luamake"

lm:lua_src "motion_sampler" {
    deps = {
        "ozz-animation-runtime",
    },
    includes = {
        lm.AntDir .. "/3rd/math3d",
        lm.AntDir .. "/3rd/luaecs",
        lm.AntDir .. "/3rd/ozz-animation/include",
        lm.AntDir .. "/clibs/ecs",
    },
    sources = {
        "tween.cpp",
        "motion_sampler.cpp",
    },
    objdeps = "compile_ecs",
}