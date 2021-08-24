local lm = require "luamake"

dofile "../common.lua"

lm:source_set "Meshbaker" {
    includes = {
        "./Meshbaker",
        "./Meshbaker/BakingLab",
        "./Meshbaker/SampleFramework11/v1.02"
    },
    sources = {
        "./Meshbaker/BakingLab/*.cpp",
        "./Meshbaker/SampleFramework11/v1.02/Graphics/*.cpp",
        "./Meshbaker/SampleFramework11/v1.02/HosekSky/*.cpp",
        "./Meshbaker/SampleFramework11/v1.02/*.cpp",
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

lm:source_set "new_baker" {
    includes = {
        LuaInclude,
    },
    sources = {
        "./bake2.cpp",
    },
    deps = {
        "Meshbaker",
    }
}

lm:lua_dll "bake2" {
    deps = {
        "new_baker",
    }
}