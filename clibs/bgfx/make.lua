local lm = require "luamake"

dofile "../common.lua"

lm:lua_source "bgfx" {
    deps = "bx",
    includes = {
        BgfxInclude,
    },
    sources = {
        "*.c",
        "*.cpp"
    },
    defines = "BX_CONFIG_DEBUG=" .. (lm.mode == "debug" and 1 or 0),
    msvc = {
        flags = {
            "-wd4244",
            "-wd4267",
        }
    },
}
