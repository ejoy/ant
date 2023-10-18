local lm = require "luamake"

local ROOT <const> = "../../"

lm:lua_source "font" {
    includes = {
        ROOT .. "3rd/bgfx/include",
        ROOT .. "3rd/bx/include",
        ROOT .. "3rd/bgfx/3rdparty",
        ROOT .. "clibs/bgfx"
    },
    sources = {
        "src/*.c",
    },
    msvc = {
        flags = {
            "-wd4244",
        }
    },
}
