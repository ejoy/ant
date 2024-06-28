local lm = require "luamake"

lm:dll "lua54" {
	includes = {
		lm.AntDir .. "/3rd/bee.lua/3rd/lua",
	},
    windows = {
        defines = "LUA_BUILD_AS_DLL",
    },
    sources = "lua_api_register.c",
    objdeps = "gen_lua_forward",
}

lm:lua_src "luaforward" {
	sources = "lua_forward.c",
    objdeps = "gen_lua_forward",
}

lm:runlua "gen_lua_forward" {
    script = "gen.lua",
    args = {
		"$in",
    },
	inputs = {
		"lua_api_register.temp.h",
		"lua_api_register.temp.c",
		"lua_forward.temp.c",
	},
    outputs = {
		"lua_api_register.h",
		"lua_api_register.c",
		"lua_forward.c",
	},
}