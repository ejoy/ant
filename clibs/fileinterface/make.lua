local lm = require "luamake"

dofile "../common.lua"

lm:source_set "source_fileinterface" {
    includes = {
        LuaInclude,
    },
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
