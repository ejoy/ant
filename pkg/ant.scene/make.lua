local lm = require "luamake"

lm:lua_source "scene" {
    confs = { "glm" },
    includes = {
        lm.AntDir .. "/clibs/ecs",
        lm.AntDir .. "/3rd/math3d",
        lm.AntDir .. "/3rd/luaecs",
    },
    sources = {
        "scene.cpp"
    },
    deps = "foundation",
    objdeps = "compile_ecs",
}
