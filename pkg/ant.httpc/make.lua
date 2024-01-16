local lm = require "luamake"

local ROOT <const> = "../../"

lm:lua_source "httpc" {
	includes = {
		ROOT .. "3rd/bee.lua",
    },
	windows = {
		sources = {
			"src/download_win.c",
		},
		links = "urlmon",
	},
	macos = {
		sources = {
			"src/download.mm",
		},
		flags = {
			"-fobjc-arc"
		},
	},
	ios = {
		sources = {
			"src/download.mm",
		},
		flags = {
			"-fobjc-arc"
		},
	},
}
