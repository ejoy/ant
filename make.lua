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

lm.AntDir = lm:path "."

lm:conf {
    compile_commands = "build",
    mode = "debug",
    c = "c17",
    cxx = "c++20",
    --TODO
    visibility = "default",
    defines = {
        "BGFX_CONFIG_DEBUG_UNIFORM=0",
        "GLM_ENABLE_EXPERIMENTAL",
        "GLM_FORCE_QUAT_DATA_XYZW",
        "GLM_FORCE_INTRINSICS",
    },
    msvc = {
        defines = {
            "_CRT_SECURE_NO_WARNINGS",
            "_WIN32_WINNT=0x0601",
        },
        flags = {
            "/utf-8",
            "/arch:AVX2",
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

lm.builddir = ("build/%s/%s"):format(plat, lm.mode)
lm.bindir = ("bin/%s/%s"):format(plat, lm.mode)

if lm.sanitize then
    lm.builddir = ("build/%s/sanitize"):format(plat)
    lm.bindir = ("bin/%s/sanitize"):format(plat)
    lm:conf {
        mode = "debug",
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
        outputs = lm.bindir,
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

if lm.os ~= "ios" and lm.os ~= "android" then
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
        lm.compiler == "msvc" and lm.sanitize and "copy_asan",
    }
else
    lm:default {
        "runtime",
    }
end
