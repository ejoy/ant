local lm = require "luamake"

dofile "../common.lua"

lm:source_set "source_font" {
    includes = {
        LuaInclude,
        BgfxInclude,
        Ant3rd .. "bgfx/3rdparty",
        "../bgfx"
    },
    sources = {
        "*.c",
        "!luabgfxui.c"
    },
    msvc = {
        flags = {
            "-wd4244",
        }
    },
}

lm:lua_dll "font" {
    includes = {
        LuaInclude,
        BgfxInclude,
        Ant3rd .. "bgfx/3rdparty",
        "../bgfx"
    },
    sources = {
        "*.c",
        "!luabgfxui.c"
    },
    msvc = {
        flags = {
            "-wd4244",
        },
        ldflags = {
            "-export:luaopen_font_init",
            "-export:luaopen_font_truetype",
        }
    },
}
