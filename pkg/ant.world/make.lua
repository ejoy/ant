local lm = require "luamake"

lm:lua_src "ecs" {
    confs = { "glm" },
    includes = {
        lm.AntDir .. "/clibs/ecs",
        lm.AntDir .. "/3rd/math3d",
        lm.AntDir .. "/3rd/luaecs",
    },
    sources = {
        "src/*.cpp"
    },
    objdeps = "compile_ecs",
}
