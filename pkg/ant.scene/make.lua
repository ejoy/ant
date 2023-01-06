local lm = require "luamake"

local ROOT <const> = "../../"

lm:lua_source "scene" {
    includes = {
		ROOT .. "clibs/ecs",
        ROOT .. "3rd/math3d",
		ROOT .. "3rd/luaecs",
        ROOT .. "3rd/glm",
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
