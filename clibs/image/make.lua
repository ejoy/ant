local lm = require "luamake"

dofile "../common.lua"

lm:source_set "source_image" {
    deps = {
        "bimg_decode",
        "bimg",
        "bx",
    },
    includes = {
        LuaInclude,
        BgfxInclude,
        Ant3rd .. "bimg/include",
        "../bgfx",
        "../lua2struct"
    },
    sources = {
        "image.cpp",
    },
}

lm:lua_dll "image" {
    deps = "source_image",
}
