local lm = require "luamake"

local sources = {
    "3rdparty/meshoptimizer/src/**.cpp",
    "3rdparty/dear-imgui/**.cpp",
    "examples/common/**.cpp",
}

lm:lib "example-common" {
    rootdir = "../bgfx/",
    includes = {
        "../bx/include",
        "../bimg/include",
        "include",
        "3rdparty",
    },
    sources = sources,
    msvc = {
        defines = {
            "_CRT_SECURE_NO_WARNINGS",
            "__STDC_FORMAT_MACROS",
        },
        includes = "../bx/include/compat/msvc",
    },
    mingw = {
        includes = "../bx/include/compat/mingw",
    },
    macos = {
        sources = {
            "examples/common/**.mm"
        }
    }
}

