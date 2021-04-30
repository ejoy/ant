local lm = require "luamake"

dofile "../common.lua"

lm:source_set "source_terrain" {
    includes = {
        LuaInclude,
        Ant3rd .. "glm"
    },
    sources = {
        "terrain.cpp",
    }
}

lm:lua_dll "terrain" {
    deps = "source_terrain"
}
