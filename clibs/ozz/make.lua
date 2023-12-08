local lm = require "luamake"

dofile "../common.lua"

lm:lua_source "ozz" {
    deps = {
        "ozz-animation-base",
        "ozz-animation-runtime",
        "ozz-animation-offline",
        "ozz-animation-geometry",
        "bx",
    },
    includes = {
        BgfxInclude,
        Ant3rd .. "ozz-animation/include",
        Ant3rd .. "bee.lua",
        "../luabind",
    },
    sources = {
        "animation.cpp",
        "ozz.cpp",
        "skeleton.cpp",
        "skinning.cpp",
    },
    defines = {
        "BX_CONFIG_DEBUG=" .. (lm.mode == "debug" and 1 or 0),
    },
}
