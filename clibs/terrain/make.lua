local lm = require "luamake"

dofile "../common.lua"

lm:source_set "source_terrain" {
    includes = {
        LuaInclude,
        Ant3rd .. "glm"
    },
    sources = {
        "terrain.cpp",
    },
    defines = {
        "GLM_FORCE_QUAT_DATA_XYZW",
    },
}

lm:lua_dll "terrain" {
    deps = "source_terrain"
}
