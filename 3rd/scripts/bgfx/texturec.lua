local lm = require "luamake"

lm:exe "texturec" {
    rootdir = "../bimg/",
    deps = {
        "bimg_decode",
        "bimg_encode",
        "bimg",
        "bx",
    },
    includes = {
        "../bx/include",
        "../bgfx/include",
        "include",
        "3rdparty/iqa/include"
    },
    sources = {
        "tools/texturec/texturec.cpp",
    },
    windows = {
        links = {
            "psapi"
        }
    },
    msvc = {
        defines = "_CRT_SECURE_NO_WARNINGS",
        includes = "../bx/include/compat/msvc",
    },
    mingw = {
        includes = "../bx/include/compat/mingw",
    },
    macos = {
        includes = "../bx/include/compat/osx",
        frameworks = {
            "Cocoa"
        }
    }
}
