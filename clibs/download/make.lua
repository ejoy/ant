local lm = require "luamake"

dofile "../common.lua"

lm:lua_source "download" {
	includes = {
		Ant3rd .. "bee.lua",
	},
	windows = {
		sources = {
			"download_win.c",
		},
		links = "urlmon",
	},
	macos = {
		sources = {
			"download.mm",
		},
		flags = {
			"-fobjc-arc"
		},
	},
	ios = {
		sources = {
			"download.mm",
		},
		flags = {
			"-fobjc-arc"
		},
	},
}
