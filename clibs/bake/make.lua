local lm = require "luamake"

dofile "../common.lua"
local GlmInclude = Ant3rd .. "glm"

lm:source_set "source_lightmap_radiosity" {
    includes = {
        LuaInclude,
        GlmInclude,
        BgfxInclude,
        "../lua2struct",
        "../bgfx",
    },
    sources = {
        "lightmapper.cpp",
    },
}

lm:lua_dll "bake" {
    deps = {
        "source_lightmap_radiosity",
    },
}
