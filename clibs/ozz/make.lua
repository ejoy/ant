local lm = require "luamake"

lm:import "ozz-animation.lua"

lm:lua_src "ozz" {
    deps = {
        "ozz-animation-base",
        "ozz-animation-runtime",
    },
    includes = {
        lm.AntDir .. "/3rd/ozz-animation/include",
        lm.AntDir .. "/3rd/bee.lua",
        "../luabind",
    },
    sources = {
        "ozz.cpp",
        "animation.cpp",
        "job.cpp",
        "skeleton.cpp",
        "skinning.cpp",
    },
}

lm:lua_src "ozz" {
    deps = {
        "ozz-animation-offline",
    },
    includes = {
        lm.AntDir .. "/3rd/ozz-animation/include",
        lm.AntDir .. "/3rd/bee.lua",
        "../luabind",
    },
    sources = {
        "offline.cpp",
    },
}
