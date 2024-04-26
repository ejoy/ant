local lm = require "luamake"

lm:lua_src "scene" {
    confs = { "glm" },
    includes = {
        lm.AntDir .. "/clibs/ecs",
        lm.AntDir .. "/3rd/math3d",
        lm.AntDir .. "/3rd/bee.lua",
        lm.AntDir .. "/3rd/luaecs",
    },
    sources = {
        "scene.cpp"
    },
    deps = "foundation",
    objdeps = "compile_ecs",
}
