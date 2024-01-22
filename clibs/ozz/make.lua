local lm = require "luamake"

lm:import "ozz-animation.lua"

lm:lua_source "ozz" {
    deps = {
        "ozz-animation-base",
        "ozz-animation-runtime",
        "ozz-animation-offline",
        "ozz-animation-geometry",
    },
    includes = {
        lm.AntDir .. "/3rd/ozz-animation/include",
        lm.AntDir .. "/3rd/bee.lua",
        "../luabind",
    },
    sources = {
        "*.cpp",
    },
}
