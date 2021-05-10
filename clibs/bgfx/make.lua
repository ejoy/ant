local lm = require "luamake"

dofile "../common.lua"

lm:source_set "source_bgfx" {
    includes = {
        LuaInclude,
        BgfxInclude,
        "../thread",
    },
    sources = {
        "*.c",
        "bgfx_alloc.cpp"
    },
    defines = {
        lm.mode == "debug" and "BGFX_CONFIG_DEBUG",
    },
    links = {
        "bx"..lm.mode,
    },
    linkdirs = BgfxLinkdir,
    msvc = {
        flags = {
            "-wd4244",
            "-wd4267",
        }
    },
}

lm:lua_dll "bgfx" {
    deps = "source_bgfx",
}
