local lm = require "luamake"

dofile "../common.lua"

lm:source_set "source_image" {
    includes = {
        LuaInclude,
        BgfxInclude,
        Ant3rd .. "bimg/include"
    },
    sources = {
        "image.cpp",
    },
    links = {
        "bimg_decode"..lm.mode,
        "bimg"..lm.mode,
        "bx"..lm.mode,
    },
    msvc = {
        includes = Ant3rd .. "bx/include/compat/msvc",
        linkdirs = Ant3rd .. "bgfx/.build/win64_vs2019/bin",
    },
    mingw = {
        includes = Ant3rd .. "bx/include/compat/mingw",
        linkdirs = Ant3rd .. "bgfx/.build/win64_mingw-gcc/bin",
    },
    macos = {
        linkdirs = Ant3rd .. "bgfx/.build/osx-arm64/bin",
    },
}

lm:lua_dll "image" {
    deps = "source_image",
}
