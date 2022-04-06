local lm = require "luamake"

dofile "../common.lua"

lm:lua_source "window" {
    includes = {
        Ant3rd.."bee.lua/3rd/lua-seri",
    },
    sources = {
        "window.c",
    },
    windows = {
        sources = {
            "mingw/mingw_window.c",
        },
        links = {
            "user32",
            "shell32",
        },
    },
    macos = {
        sources = {
            "osx/osx_window.m",
        },
    },
    ios = {
        sources = {
            "ios/ios_window.m",
        },
    }
}
