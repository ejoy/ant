local lm = require "luamake"

lm:lua_source "textureman" {
	includes = {
		"../../clibs/bgfx",
		"../../3rd/bgfx/include",
		"../../3rd/bx/include",
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
