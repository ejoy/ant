local lm = require "luamake"

local ROOT <const> = "../../"

lm:lua_source "window" {
    includes = {
        ROOT.."3rd/bee.lua/3rd/lua-seri",
        ROOT.."3rd/bee.lua",
        ROOT.."3rd/imgui",
    },
    sources = {
        "src/*.cpp",
    },
    windows = {
        sources = {
            "src/platform/windows/*.cpp",
            "src/peek/*.cpp",
        },
        links = {
            "user32",
            "shell32",
        },
    },
    macos = {
        sources = {
            "src/platform/osx/*.mm",
            "src/peek/*.cpp",
        },
    },
    ios = {
        sources = {
            "src/platform/ios/*.mm",
            "src/loop/*.cpp",
        },
    },
    android = {
        includes = {
            "src/platform/android/include",
            ROOT.."runtime/common",
        },
        sources = {
            "src/platform/android/include/**/*.cpp",
            "src/platform/android/include/**/*.c",
            "src/platform/android/*.cpp",
            "src/peek/*.cpp",
        },
    }
}
