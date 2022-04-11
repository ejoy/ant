local lm = require "luamake"

dofile "../common.lua"

lm:lua_source "rp3d" {
    deps = "reactphysics3d",
    includes = {
        Ant3rd .. "reactphysics3d/include"
    },
    sources = {
        "lua-rp3d.cpp",
    }
}
