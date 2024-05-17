do return end

local lm = require "luamake"
local fs = require "bee.filesystem"

lm.defines = lm.mode ~= "release" and "_DEBUG"

lm:source_set "Meshbaker" {
    confs = { "glm" },
    includes = {},
    sources = {
        "./path_tracer/BakerInterface.cpp"
    },
    defines = {
        "_UNICODE",
        "UNICODE",
    },
    cxx = "c++14",
    linkdirs = {},
}

local inputpaths = {}

local outputpaths = {}

for idx, d in ipairs(inputpaths) do
    outputpaths[idx] = "$bin/" .. fs.path(d):filename():string()
end

lm:lua_src "bake" {
    includes = {
        GLMInclude,
        "../luabind",
        "../bgfx",
    },
    sources = {
        "./path_tracer/lbake.cpp",
    },
    deps = {}
}

lm:source_set "radiosity_lightmapper" {
    sources = {
        "radiosity/lightmapper.cpp",
    }
}
