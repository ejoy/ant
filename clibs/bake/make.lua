do return end

local lm = require "luamake"
local fs = require "bee.filesystem"

lm.defines = lm.mode ~= "release" and "_DEBUG"

local GLMInclude = lm.AntDir .. "/3rd/glm"
lm:source_set "Meshbaker" {
    includes = {
        GLMInclude,
        "./Meshbaker",
        "./Meshbaker/BakingLab",
        "./Meshbaker/SampleFramework11/v1.02",
    },
    sources = {
        "./Meshbaker/BakingLab/*.cpp",
        "./Meshbaker/SampleFramework11/v1.02/Graphics/*.cpp",
        "./Meshbaker/SampleFramework11/v1.02/HosekSky/*.cpp",
        "./Meshbaker/SampleFramework11/v1.02/*.cpp",
        "./path_tracer/BakerInterface.cpp"
    },
    defines = {
        "_UNICODE",
        "UNICODE",
        [[SampleFrameworkDir_=L\"clibs/bake/Meshbaker/SampleFramework11/v1.02/\"]],
        [[ContentDir_=L\"clibs/bake/Meshbaker/Content/\"]],
        [[BakingLabDir_=L\"clibs/bake/Meshbaker/BakingLab/\"]],
    },
    cxx = "c++14",
    linkdirs = {
        "./Meshbaker/Externals/DirectXTex Aug 2015/Lib 2015 Win7/" .. lm.mode,
        "./Meshbaker/Externals/Embree-2.8/lib"
    },
}

local inputpaths = {
    "./Meshbaker/Externals/Embree-2.8/lib/embree.dll",
    "./Meshbaker/Externals/Embree-2.8/lib/tbb.dll",
    "./Meshbaker/Externals/Embree-2.8/lib/tbbmalloc.dll",
}

local outputpaths = {}

for idx, d in ipairs(inputpaths) do
    outputpaths[idx] = "$bin/" .. fs.path(d):filename():string()
end

lm:copy "copy_Meshbaker" {
    inputs = inputpaths,
    outputs = outputpaths,
}

lm:lua_source "bake" {
    includes = {
        GLMInclude,
        "../luabind",
        "../bgfx",
    },
    sources = {
        "./path_tracer/lbake.cpp",
    },
    deps = {
        "Meshbaker",
        "copy_Meshbaker",
    }
}

lm:source_set "radiosity_lightmapper" {
    sources = {
        "radiosity/lightmapper.cpp",
    }
}
