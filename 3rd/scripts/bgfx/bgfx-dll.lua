local lm = require "luamake"

lm:dll "bgfx-core" {
    rootdir = "../bgfx/",
    deps = {"bx", "bimg"},
    defines = {
        "BGFX_SHARED_LIB_BUILD=1",
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
        links = { "gdi32", "psapi", "user32" }
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
        },
        frameworks = {
            "Cocoa",
            "QuartzCore",
            "OpenGL",
        },
        ldflags = {
            "-weak_framework", "Metal",
            "-weak_framework", "MetalKit",
        }
    }
}
