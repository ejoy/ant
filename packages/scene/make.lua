local lm = require "luamake"

lm:lua_source "scene" {
    includes = {
		"../../clibs/ecs",
        "../../3rd/math3d",
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
