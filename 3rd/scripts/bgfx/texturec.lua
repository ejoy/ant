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
        sources = "../scripts/utf8/utf8.rc",
        links = {
            "psapi"
        }
    },
    macos = {
        frameworks = {
            "Cocoa"
        }
    }
}
