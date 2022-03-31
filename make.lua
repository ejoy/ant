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

local EnableEditor = true
if lm.os == "ios" then
    lm.arch = "arm64"
    EnableEditor = false
    if lm.mode == "release" then
        lm.sys = "ios13.0"
    else
        lm.sys = "ios14.1"
    end
end

lm.c = "c11"
lm.cxx = "c++20"
lm.msvc = {
    defines = "_CRT_SECURE_NO_WARNINGS",
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

--TODO
lm.visibility = "default"

lm:import "3rd/scripts/bgfx.lua"
lm:import "3rd/scripts/ozz-animation.lua"
lm:import "3rd/scripts/reactphysics3d.lua"
lm:import "3rd/scripts/sdl.lua"
lm:import "runtime/make.lua"

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
