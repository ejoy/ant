local lm = require "luamake"

lm:lua_source "httpc" {
	includes = {
		lm.AntDir .. "/3rd/bee.lua",
	},
	windows = {
		sources = {
			"src/download_win.c",
		},
		links = "urlmon",
	},
	macos = {
		sources = {
			"src/httpc.mm",
		},
		flags = {
			"-fobjc-arc"
		},
	},
	ios = {
		sources = {
			"src/httpc.mm",
		},
		flags = {
			"-fobjc-arc"
		},
	},
}
