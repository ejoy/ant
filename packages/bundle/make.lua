local lm = require "luamake"

lm:lua_source "textureman" {
	includes = {
		"../../clibs/bgfx",
	},
    sources = {
        "src/textureman.c",
    }
}

lm:lua_source "bundle" {
    deps = "textureman",
    sources = {
        "src/bundle.c",
    }
}
