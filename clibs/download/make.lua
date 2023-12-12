local lm = require "luamake"

lm:lua_source "download" {
	windows = {
		sources = {
			"download_win.c",
		},
		links = "urlmon",
	},
}
