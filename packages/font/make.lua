local lm = require "luamake"

lm:lua_source "layout"{
    deps={
        "font",
    },
    includes = {
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

