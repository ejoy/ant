local lm = require "luamake"

lm:lua_source "layout"{
    deps={
        "font",
    },
    includes = {
        "../../3rd/bee.lua/3rd/lua",
        "../../clibs/font",
        "../../clibs/bgfx",
        "../../3rd/bgfx/include",
        "../../3rd/bx/include",
        "../../3rd/bgfx/3rdparty",
    },
    sources = {
        "layout.cpp",
    }
}

