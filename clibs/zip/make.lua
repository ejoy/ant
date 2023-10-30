local lm = require "luamake"

dofile "../common.lua"

local MINIZ = Ant3rd .. "zlib/contrib/minizip/"

lm:lua_source "zip" {
    windows = {
        sources = {
			MINIZ .. "iowin32.c",
        },
    },
	includes = {
		Ant3rd .. "zlib",
		MINIZ,
    },
	sources = {
		Ant3rd .. "zlib/*.c",
		MINIZ .. "ioapi.c",
		MINIZ .. "unzip.c",
		MINIZ .. "zip.c",
		"*.c",
	},
}
