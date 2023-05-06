local lm = require "luamake"

dofile "../common.lua"

lm:lua_source "platform" {
    includes = {
        BgfxInclude,
    },
    sources = {
        "lplatform.cpp",
    },
    windows = {
        sources = {
            "win32/*.cpp"
        },
        links = {
            "gdi32",
            "user32",
            "ole32",
            "oleaut32",
            "wbemuuid",
        },
    },
    macos = {
        sources = {
            "osx/*.mm",
        },
        frameworks = {
            "AppKit"
        }
    },
    ios = {
        sources = {
            "osx/*.mm",
            "!osx/platform.mm",
            "ios/*.mm",
            "ios/*.m",
        }
    }
}
