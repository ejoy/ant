local lm = require "luamake"

local ROOT <const> = "../../"

lm:lua_source "ecs" {
    includes = {
        ROOT .. "clibs/ecs",
        ROOT .. "3rd/math3d",
        ROOT .. "3rd/luaecs",
        ROOT .. "3rd/glm",
    },
    sources = {
        "src/*.cpp"
    },
    objdeps = "compile_ecs",
}
