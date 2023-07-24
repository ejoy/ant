local lm = require "luamake"

local ROOT <const> = "../../"

local includes = {
    ROOT .. "clibs/bgfx",
    ROOT .. "3rd/bgfx/include",
    ROOT .. "3rd/bx/include",
}

lm:lua_source "textureman" {
	includes = includes,
    sources = "src/textureman.c",
}

lm:lua_source "programan"{
    includes = includes,
    sources = "src/programan.c",
}

lm:lua_source "bundle" {
    deps = {
        "textureman",
        "programan",
    },
    sources = "src/bundle.c",
}
