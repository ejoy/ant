local lm = require "luamake"

lm:lua_source "bundle" {
    sources = {
        "src/bundle.c",
    }
}

lm:lua_source "textureman" {
	includes = {
		"../../clibs/bgfx",
	},
    sources = {
        "src/textureman.c",
    }
}
