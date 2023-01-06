local lm = require "luamake"

local ROOT <const> = "../../"

lm:lua_source "layout"{
    deps={
        "font",
    },
    includes = {
        ROOT .. "clibs/font",
        ROOT .. "clibs/bgfx",
        ROOT .. "3rd/bgfx/include",
        ROOT .. "3rd/bx/include",
        ROOT .. "3rd/bgfx/3rdparty",
    },
    sources = {
        "layout.cpp",
    }
}

