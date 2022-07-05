local lm = require "luamake"

lm:lua_source "scene" {
    includes = {
        "../../clibs/lua",
        "../../clibs/math3d",
		"../../clibs/foundation",
		"../../clibs/ecs",
		"../../3rd/luaecs",
    },
    sources = {
        "scene.c"
    },
    deps = "foundation",
    objdeps = "compile_ecs",
}
