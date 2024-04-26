local lm = require "luamake"

lm:lua_src "httpc" {
	includes = {
		lm.AntDir .. "/3rd/bee.lua",
	},
	windows = {
		sources = {
			"src/httpc.cpp",
		},
		links = {
			"Wininet",
		}
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
