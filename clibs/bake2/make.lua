local lm = require "luamake"
local fs = require "bee.filesystem"

dofile "../common.lua"

local GLMInclude = Ant3rd .. "glm"
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
        "./BakerInterface.cpp"
    },
    defines = {
        "Debug_",
        "WIN32",
        "_DEBUG",
        "_WINDOWS",
        "_UNICODE",
        "UNICODE",
        [[SampleFrameworkDir_=L\"Meshbaker/SampleFramework11/v1.02\"]],
    },
    cxx = "c++14",
    linkdirs = {
        "./Meshbaker/Externals/Assimp-3.1.1/lib",
        "./Meshbaker/Externals/AntTweakBar/lib",
        "./Meshbaker/Externals/DirectXTex Aug 2015/Lib 2015 Win7/" .. lm.mode,
        "./Meshbaker/Externals/Embree-2.8/lib"
    },
}

local inputpaths = {
    "./Meshbaker/Externals/Assimp-3.1.1/bin/assimp.dll",
    "./Meshbaker/Externals/AntTweakBar/bin/AntTweakBar64.dll",
    "./Meshbaker/Externals/Embree-2.8/lib/embree.dll",
    "./Meshbaker/Externals/Embree-2.8/lib/tbb.dll",
    "./Meshbaker/Externals/Embree-2.8/lib/tbbmalloc.dll",
}

local outputpaths = {}

for idx, d in ipairs(inputpaths) do
    outputpaths[idx] = BinDir .. fs.path(d):filename():string()
end

lm:copy "copy_Meshbaker" {
    input = inputpaths,
    output = outputpaths,
}

lm:source_set "new_baker" {
    includes = {
        LuaInclude,
        GLMInclude,
    },
    sources = {
        "./bake2.cpp",
    },
    deps = {
        "Meshbaker",
        "copy_Meshbaker",
    }
}

lm:lua_dll "bake2" {
    deps = {
        "new_baker",
    }
}