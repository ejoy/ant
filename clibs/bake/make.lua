local lm = require "luamake"

dofile "../common.lua"
local GlmInclude = Ant3rd .. "glm"

lm:source_set "source_bake" {
    includes = {
        LuaInclude,
        BgfxInclude,
        GlmInclude,
        "../lua2struct",
        "../bgfx",
    },
    sources = {
        "lightmapper.cpp",
        "baker.cpp",
        "Meshbaker/*.cpp",
    },
    links = {
        "embree"
    },
    linkdirs = {
        "Meshbaker/Embree-2.8/lib",
    }
}

lm:lua_dll "bake" {
    deps = "source_bake"
}
