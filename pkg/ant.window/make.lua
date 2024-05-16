local lm = require "luamake"

lm:lua_src "window" {
    includes = {
        lm.AntDir .. "/3rd/bee.lua",
        lm.AntDir .. "/3rd/imgui",
    },
    sources = {
        "src/*.cpp",
    },
    windows = {
        sources = {
            "src/platform/windows/*.cpp",
        },
        links = {
            "user32",
            "shell32",
        },
    },
    macos = {
        sources = {
            "src/platform/osx/*.mm",
        },
    },
    linux = {
        sources = {
            "src/platform/linux/*.cpp",
        },
        links = {
            "X11",
        },
    },
    ios = {
        sources = {
            "src/platform/ios/*.mm",
        },
    },
    android = {
        includes = {
            "src/platform/android/include",
            lm.AntDir .. "/runtime/common",
        },
        sources = {
            "src/platform/android/include/**/*.cpp",
            "src/platform/android/include/**/*.c",
            "src/platform/android/*.cpp",
            "src/peek/*.cpp",
        },
    }
}
