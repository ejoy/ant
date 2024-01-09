local lm = require "luamake"

local ROOT <const> = "../../"

lm:lua_source "font-systemfont" {
    includes = {
        ROOT .. "clibs/zip"
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
        ROOT .. "3rd/bgfx/include",
        ROOT .. "3rd/bx/include",
        ROOT .. "3rd/bgfx/3rdparty",
        ROOT .. "clibs/bgfx"
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
