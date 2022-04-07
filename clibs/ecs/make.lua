local lm = require "luamake"

dofile "../common.lua"

lm:copy "copy_ecs_lua" {
    input = Ant3rd .. "luaecs/ecs.lua",
    output = "../../packages/luaecs/ecs.lua"
}

lm:lua_source "ecs" {
    deps = "copy_ecs_lua",
    sources = Ant3rd .. "luaecs/luaecs.c",
}
