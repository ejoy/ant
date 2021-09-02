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
        defines = "__STDC_FORMAT_MACROS",
    },
    macos = {
        sources = {
            "src/*.mm",
            "!src/amalgamated.mm",
        },
        flags = {
            "-x", "objective-c++"
        }
    },
    ios = {
        defines = {
            "BGFX_CONFIG_RENDERER_METAL=1",
        },
        sources = {
            "src/*.mm",
            "!src/amalgamated.mm",
        }
    }
}
