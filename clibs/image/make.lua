local lm = require "luamake"

dofile "../common.lua"

lm:source_set "source_image" {
    deps = {
        "bimg_decode",
        "bimg",
        "bx",
    },
    defines = "BX_CONFIG_DEBUG=" .. (lm.mode == "debug" and 1 or 0),
    includes = {
        LuaInclude,
        BgfxInclude,
        Ant3rd .. "bimg/include",
        "../bgfx",
        "../luabind"
    },
    sources = {
        "image.cpp",
    },
}

lm:lua_dll "image" {
    deps = "source_image",
}
