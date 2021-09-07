local lm = require "luamake"

lm:copy "copy_bgfx_shader" {
    input = {
        "../bgfx/src/bgfx_shader.sh",
        "../bgfx/src/bgfx_compute.sh",
        "../bgfx/examples/common/common.sh",
        "../bgfx/examples/common/shaderlib.sh",
    },
    output = {
        "../../packages/resources/shaders/bgfx_shader.sh",
        "../../packages/resources/shaders/bgfx_compute.sh",
        "../../packages/resources/shaders/common.sh",
        "../../packages/resources/shaders/shaderlib.sh",
    }
}

lm:dll "bgfx-core" {
    rootdir = "../bgfx/",
    deps = {
        "bx",
        "bimg",
        "copy_bgfx_shader"
    },
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
    msvc = {
        defines = "__STDC_FORMAT_MACROS",
    },
    clang = {
        flags = {
            "-Wno-unused-variable"
        }
    },
    windows = {
        includes = "3rdparty/dxsdk/include",
        links = { "gdi32", "psapi", "user32" }
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
