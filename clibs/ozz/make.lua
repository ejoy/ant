local lm = require "luamake"

dofile "../common.lua"

lm:lua_source "ozz" {
    deps = {
        "ozz-animation-base",
        "ozz-animation-runtime",
        "ozz-animation-offline",
        "ozz-animation-geometry",
    },
    includes = {
        Ant3rd .. "ozz-animation/include",
        Ant3rd .. "bee.lua",
        "../luabind",
    },
    sources = {
        "*.cpp",
    },
}
