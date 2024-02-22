local lm = require "luamake"

lm:required_version "1.6"
--lm.luaversion = "lua55"

local plat = (function ()
    if lm.os == "windows" then
        if lm.compiler == "gcc" then
            return "mingw"
        end
        if lm.cc == "clang-cl" then
            return "clang_cl"
        end
        return "msvc"
    end
    return lm.os
end)()

lm.mode = "debug"
lm.builddir = ("build/%s/%s"):format(plat, lm.mode)
lm.bindir = ("bin/%s/%s"):format(plat, lm.mode)
lm.compile_commands = "build"

lm.AntDir = lm:path "."

local EnableEditor = lm.os ~= "ios" and lm.os ~= "android"

lm:conf {
    c = "c17",
    cxx = "c++20",
    --TODO
    visibility = "default",
    defines = "BGFX_CONFIG_DEBUG_UNIFORM=0",
    msvc = {
        defines = {
            "_CRT_SECURE_NO_WARNINGS",
            "_WIN32_WINNT=0x0601",
        },
        flags = {
            "/utf-8",
            "/wd5105"
        },
        ldflags = lm.mode == "release" and {
            "/DEBUG:FASTLINK"
        }
    },
    ios = {
        arch = "arm64",
        sys = "ios16.0",
        flags = {
            "-fembed-bitcode",
            "-fobjc-arc"
        }
    },
    android  = {
        flags = "-fPIC",
        arch = "aarch64",
        vendor = "linux",
        sys = "android33",
    }
}

local EnableSanitize = false

if EnableSanitize then
    lm.builddir = ("build/%s/sanitize"):format(plat)
    lm.bindir = ("bin/%s/sanitize"):format(plat)
    lm.mode = "debug"
    lm:conf {
        flags = "-fsanitize=address",
        gcc = {
            ldflags = "-fsanitize=address"
        },
        clang = {
            ldflags = "-fsanitize=address"
        }
    }
    lm:msvc_copydll "copy_asan" {
        type = "asan",
        output = lm.bindir,
    }
end

lm:import "runtime/make.lua"

lm:runlua "compile_ecs" {
    script = "clibs/ecs/ecs_compile.lua",
    args = {
        lm.AntDir,
        "$out",
        "@pkg",
    },
    inputs = "pkg/**/*.ecs",
    output = "clibs/ecs/ecs/component.hpp",
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
    lm:default {
        "editor",
        EnableSanitize and "copy_asan",
    }
else
    lm:default {
        "runtime",
        EnableSanitize and "copy_asan",
    }
end
