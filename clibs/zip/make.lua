local lm = require "luamake"

dofile "../common.lua"

lm:lua_source "minizip" {
	rootdir = Ant3rd .. "zlib/contrib/minizip",
	windows = {
		sources = "contrib/minizip/iowin32.c",
	},
	includes = "contrib/minizip",
	sources = {
		"ioapi.c",
		"unzip.c",
		"zip.c",
	},
}

lm:lua_source "zlib" {
	rootdir = Ant3rd .. "zlib",
	sources = {
		"*.c",
		"!gz*.c",
	},
}

lm:lua_source "zip-binding" {
	includes = {
		Ant3rd .. "zlib",
		Ant3rd .. "zlib/contrib/minizip",
	},
	sources = "*.c",
}

lm:lua_source "zip" {
	deps = {
		"zlib",
		"minizip",
		"zip-binding",
	}
}
