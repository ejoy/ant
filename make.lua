local lm = require "luamake"

local plat = (function ()
    if lm.os == "windows" then
        if lm.compiler == "gcc" then
            return "mingw"
        end
        return "msvc"
    end
    return lm.os
end)()

lm.mode = "debug"
lm.builddir = ("build/%s/%s"):format(plat, lm.mode)
lm.bindir = ("bin/%s/%s"):format(plat, lm.mode)
lm.compile_commands = "build"

local EnableEditor = true
if lm.os == "ios" then
    lm.arch = "arm64"
    lm.sys = "ios15.0"
    EnableEditor = false
end

if lm.os == "android" then
    EnableEditor = false
end

lm.c = "c17"
lm.cxx = "c++20"
lm.msvc = {
    defines = {
        "_CRT_SECURE_NO_WARNINGS",
        "_WIN32_WINNT=0x0601",
    },
    flags = {
        "-wd5105"
    }
}

lm:config "engine_config" {
    msvc = {
        flags = "/utf-8",
    },
}

lm.configs = {
    "engine_config",
    --"sanitize"
}

if lm.mode == "release" then
    lm.msvc.ldflags = {
        "/DEBUG:FASTLINK"
    }
end

lm.ios = {
    flags = {
        "-fembed-bitcode",
        "-fobjc-arc"
    }
}

lm.android  = {
    flags = "-fPIC",
}

if lm.os == "android" then
    lm.arch = "aarch64"
    lm.vendor = "linux"
    lm.sys = "android33"
end

--TODO
lm.visibility = "default"

lm:import "runtime/make.lua"

lm:runlua "compile_ecs" {
    script = "clibs/ecs/compile_ecs.lua",
    args =  {
        "@clibs/ecs/ecs/",
        "@pkg",
    },
    inputs = "pkg/**/*.ecs",
    output = {
        "clibs/ecs/ecs/component.hpp",
    }
}

if EnableEditor then
    lm:phony "tools" {
        deps = {
            "gltf2ozz",
            "shaderc",
            "texturec",
        }
    }
    lm:phony "all" {
        deps = {
            "editor",
            "runtime",
            "tools",
        }
    }
    lm:default "editor"
else
    lm:default "runtime"
end
