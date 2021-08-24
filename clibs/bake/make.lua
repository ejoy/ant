local lm = require "luamake"

dofile "../common.lua"
local GlmInclude = Ant3rd .. "glm"


lm:source_set "source_Meshbaker"{
    includes = {
        GlmInclude,
    },
    sources = {
        "Meshbaker/Graphics/Sampling.cpp",
        "Meshbaker/Graphics/SH.cpp",
        "Meshbaker/Graphics/Textures.cpp",
        "Meshbaker/SG.cpp",
        "Meshbaker/PathTracer.cpp",
        --"Meshbaker/Rasterizer.cpp",
        "Meshbaker/Setting.cpp",
        --"Meshbaker/MeshBaker.cpp",
    },
    links = {
        "embree"
    },
    linkdirs = {
        "Meshbaker/3rd/Embree-2.8/lib",
    },
    cxx = "c++14",
}

lm:source_set "new_baker"{
    includes = {
        LuaInclude,
    },
    sources = {
        "baker.cpp",
    },
    deps = {
        "source_Meshbaker",
    }
}

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
        "new_baker",
    },
}
