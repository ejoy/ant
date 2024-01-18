local lm = require "luamake"

lm:lua_source "ecs" {
    includes = {
        lm.AntDir .. "/clibs/ecs",
        lm.AntDir .. "/3rd/math3d",
        lm.AntDir .. "/3rd/luaecs",
        lm.AntDir .. "/3rd/glm",
    },
    sources = {
        "src/*.cpp"
    },
    objdeps = "compile_ecs",
}
