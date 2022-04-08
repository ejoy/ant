local lm = require "luamake"

dofile "../common.lua"

lm:lua_source "source_fileinterface" {
	defines = {
		lm.test and "FILE_INTERFACE_TEST"
	},
    sources = {
        "fileinterface.c",
    },
}

lm:lua_dll "fileinterface" {
    deps = "source_fileinterface",
}
