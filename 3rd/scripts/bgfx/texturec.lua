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
    defines = {
        "BX_CONFIG_DEBUG=" .. (lm.mode == "debug" and 1 or 0),
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
