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
    EnableEditor = false
    if lm.mode == "release" then
        lm.sys = "ios14.1"
    else
        lm.sys = "ios14.1"
    end
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
        lm.mode == "debug" and "_DISABLE_STRING_ANNOTATION",
    },
    flags = {
        "-wd5105"
    }
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

lm:import "3rd/scripts/bgfx.lua"
lm:import "3rd/scripts/ozz-animation.lua"
lm:import "3rd/scripts/reactphysics3d.lua"
lm:import "3rd/scripts/sdl.lua"
lm:import "runtime/make.lua"

lm:runlua "compile_ecs" {
    script = "projects/luamake/ecs.lua",
    args =  {
        "@pkg/ant.ecs/component.lua",
        "@clibs/ecs/ecs/",
        "@pkg",
    },
    inputs = "pkg/**/*.ecs",
    output = {
        "pkg/ant.ecs/component.lua",
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
