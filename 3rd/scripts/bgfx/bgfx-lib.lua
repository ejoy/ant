local lm = require "luamake"

lm:lib "bgfx-lib" {
    rootdir = "../bgfx/",
    deps = {"bx", "bimg"},
    defines = {
        "BGFX_CONFIG_MAX_VIEWS=1024",
        lm.mode == "debug" and "BGFX_CONFIG_DEBUG=1",
    },
    includes = {
        "../bx/include",
        "../bimg/include",
        "3rdparty",
        "3rdparty/khronos",
        "include",
    },
    sources = {
        "src/*.cpp",
        "!src/amalgamated.cpp",
    },
    windows = {
        includes = "3rdparty/dxsdk/include",
    },
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
        includes = "../bx/include/compat/osx",
        sources = {
            "src/*.mm",
            "!src/amalgamated.mm",
        },
        flags = {
            "-x", "objective-c++"
        }
    }
}
