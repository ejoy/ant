local lm = require "luamake"

dofile "../common.lua"

lm:lua_source "window" {
    includes = {
        Ant3rd.."bee.lua/3rd/lua-seri",
        Ant3rd.."bee.lua",
    },
    sources = {
        "*.cpp",
    },
    windows = {
        sources = {
            "platform/windows/*.cpp",
            "peek/*.cpp",
        },
        links = {
            "user32",
            "shell32",
        },
    },
    macos = {
        sources = {
            "platform/osx/*.mm",
            "peek/*.cpp",
        },
    },
    ios = {
        sources = {
            "platform/ios/*.mm",
            "loop/*.cpp",
        },
    },
    android = {
        includes = {
            "platform/android/include",
            Ant3rd.."../runtime/common",
        },
        sources = {
            "platform/android/include/**/*.cpp",
            "platform/android/include/**/*.c",
            "platform/android/*.cpp",
            "peek/*.cpp",
        },
    }
}
