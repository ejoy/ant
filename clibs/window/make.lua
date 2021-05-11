local lm = require "luamake"

dofile "../common.lua"

lm:source_set "source_window" {
    includes = LuaInclude,
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

lm:lua_dll "window" {
    deps = "source_window"
}
