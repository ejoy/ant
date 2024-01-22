local lm = require "luamake"

lm:lua_source "font-systemfont" {
    includes = {
        lm.AntDir .. "/clibs/zip"
    },
    windows = {
        sources = {
            "src/win32/systemfont.cpp",
        },
    },
    macos = {
        sources = {
            "src/apple/systemfont.mm",
        },
    },
    ios = {
        sources = {
            "src/apple/systemfont.mm",
        },
    },
}

lm:lua_source "font" {
    deps = "font-systemfont",
    includes = {
        lm.AntDir .. "/3rd/bgfx/include",
        lm.AntDir .. "/3rd/bx/include",
        lm.AntDir .. "/3rd/bgfx/3rdparty",
        lm.AntDir .. "/clibs/bgfx"
    },
    sources = {
        "src/*.c",
    },
    msvc = {
        flags = {
            "-wd4244",
        }
    },
}
