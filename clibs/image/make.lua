local lm = require "luamake"

dofile "../common.lua"

lm:source_set "source_image" {
    includes = {
        LuaInclude,
        BgfxInclude,
        Ant3rd .. "bimg/include",
        "../bgfx"
    },
    sources = {
        "image.cpp",
    },
    links = {
        "bimg_decode"..lm.mode,
        "bimg"..lm.mode,
        "bx"..lm.mode,
    },
    linkdirs = BgfxLinkdir,
}

lm:lua_dll "image" {
    deps = "source_image",
}
