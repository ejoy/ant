local lm = require "luamake"

dofile "../common.lua"

lm:source_set "source_rp3d" {
    includes = {
        LuaInclude,
        Ant3rd .. "reactphysics3d/include"
    },
    sources = {
        "lua-rp3d.cpp",
    },
    linkdirs = {
        Ant3rd .. lm.builddir .. "/reactphysics3d/"
    },
    links = {
        "reactphysics3d"
    },
}

lm:lua_dll "rp3d" {
    deps = "source_rp3d",
    msvc = {
        export_luaopen = false,
        ldflags = {
            "-export:luaopen_rp3d_core"
        }
    }
}
