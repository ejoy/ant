local lm = require "luamake"

dofile "../common.lua"

lm:lua_source "font" {
    includes = {
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
