local lm = require "luamake"
local fs = require "bee.filesystem"

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
    lm.sys = "ios14.1"
    EnableEditor = false
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
lm:import "runtime/make.lua"

lm:phony "runtime" {
    deps = {
        "ant",
        "runtime_modules",
    }
}

if EnableEditor then
    local Backlist = {}
    local EditorModules = {}

    for path in fs.path "clibs":list_directory() do
        if fs.exists(path / "make.lua") then
            local name = path:stem():string()
            if not Backlist[name] then
                lm:import(("clibs/%s/make.lua"):format(name))
                if EnableEditor then
                    EditorModules[#EditorModules + 1] = name
                end
            end
        end
    end

    EditorModules[#EditorModules + 1] = "bgfx-core"

    lm:phony "tools" {
        deps = {
            "gltf2ozz",
            "shaderc",
            "texturec",
        }
    }

    lm:phony "editor" {
        deps = {
            "lua",
            "luac",
            EditorModules
        }
    }
    lm:default "editor"
else
    lm:default "runtime"
end
