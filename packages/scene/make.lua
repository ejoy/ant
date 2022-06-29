local lm = require "luamake"

lm:lua_source "scene" {
    includes = {
        "../../clibs/lua",
        "../../clibs/math3d",
		"../../clibs/foundation",
		"../../3rd/luaecs",
    },
    sources = {
        "scene.c"
    }
}