local lm = require "luamake"

dofile "../common.lua"

lm:lua_source "window" {
    includes = {
        Ant3rd.."bee.lua/3rd/lua-seri",
        Ant3rd.."bee.lua",
    },
    sources = {
        "window.c",
    },
    windows = {
        sources = {
            "win32/*.c",
        },
        links = {
            "user32",
            "shell32",
        },
    },
    macos = {
        sources = {
            "osx/*.m",
        },
    },
    ios = {
        sources = {
            "ios/*.m",
            "ios/*.mm",
        },
    },
    android = {
        includes = {
            "android/include",
            Ant3rd.."../runtime/common",
        },
        sources = {
            "android/include/**/*.cpp",
            "android/include/**/*.c",
            "android/*.cpp",
        },
    }
}
