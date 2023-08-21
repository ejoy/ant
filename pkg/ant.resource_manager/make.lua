local lm = require "luamake"

local ROOT <const> = "../../"

lm:lua_source "resource_manager" {
    includes = {
        ROOT .. "clibs/bgfx",
        ROOT .. "3rd/bgfx/include",
        ROOT .. "3rd/bx/include",
    },
    sources = {
        "src/textureman.c",
        "src/programan.c",
    }
}
