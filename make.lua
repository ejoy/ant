local lm = require "luamake"

lm:required_version "1.11"
--lm.luaversion = "lua55"

local plat = (function ()
    if lm.os == "windows" then
        if lm.compiler == "gcc" then
            return "mingw"
        end
        if lm.cc == "clang-cl" then
            return "clang-cl"
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
    msvc = {
        defines = {
            "_CRT_SECURE_NO_WARNINGS",
            "_WIN32_WINNT=0x0602",
        },
        flags = {
            "/utf-8",
            "/arch:AVX2",
        }
    },
    macos = {
        sys = "macos13.3",
    },
    ios = {
        arch = "arm64",
        sys = "ios16.3",
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

lm:conf "glm" {
    defines = {
        "GLM_ENABLE_EXPERIMENTAL",
        "GLM_FORCE_QUAT_DATA_XYZW",
        "GLM_FORCE_INTRINSICS",
    },
    includes = {
        lm.AntDir .. "/3rd/glm",
    },
}

lm:conf "bgfx" {
    defines = lm.mode == "debug" and {
        "BX_CONFIG_DEBUG=1",
        "BGFX_CONFIG_DEBUG_UNIFORM=0",
    } or {
        "BX_CONFIG_DEBUG=0",
    },
    includes = {
        lm.AntDir .. "/3rd/bgfx/include",
        lm.AntDir .. "/3rd/bx/include",
        lm.os == "windows" and {
            lm.compiler == "msvc"
            and { lm.AntDir .. "/3rd/bx/include/compat/msvc" }
            or { lm.AntDir .. "/3rd/bx/include/compat/mingw" },
        }
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
    inputs = lm.AntDir.."/pkg/**/*.ecs",
    outputs = "clibs/ecs/ecs/component.hpp",
}

if lm.os ~= "ios" and lm.os ~= "android" then
    lm:phony "tools" {
        deps = {
            "gltf2ozz",
            "shaderc",
            "texturec",
            "tools_version",
        }
    }
    lm:phony "all" {
        deps = {
            "ant",
            "tools",
        }
    }
end

lm:default {
    "ant",
    lm.compiler == "msvc" and lm.sanitize and "copy_asan",
}
