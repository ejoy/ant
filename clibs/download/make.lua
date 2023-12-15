local lm = require "luamake"

if lm.os ~= "windows" then
    return
end

lm:lua_source "download" {
	windows = {
		sources = {
			"download_win.c",
		},
		links = "urlmon",
	},
}
