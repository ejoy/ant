local lm = require "luamake"

dofile "../common.lua"

lm:copy "copy_ecs_lua" {
    input = Ant3rd .. "luaecs/ecs.lua",
    output = "../../pkg/ant.luaecs/ecs.lua"
}

lm:lua_source "ecs" {
    deps = "copy_ecs_lua",
    sources = Ant3rd .. "luaecs/*.c",
    msvc = {
        flags = {
            "/wd4996",
        }
    }
}
