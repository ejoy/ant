local lm = require "luamake"

lm:lua_source "scene" {
    includes = {
        "../../clibs/lua",
        "../../clibs/math3d",
		"../../clibs/foundation",
		"../../clibs/ecs",
		"../../3rd/luaecs",
        "../../3rd/glm",
    },
    sources = {
        "scene.cpp"
    },
    defines = {
        "GLM_FORCE_QUAT_DATA_XYZW",
    },
    deps = "foundation",
    objdeps = "compile_ecs",
}
