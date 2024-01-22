local lm = require "luamake"

lm:copy "copy_ecs_lua" {
    input = lm.AntDir .. "/3rd/luaecs/ecs.lua",
    output = lm.AntDir .. "/pkg/ant.luaecs/ecs.lua"
}

lm:lua_source "ecs" {
    deps = "copy_ecs_lua",
    sources = lm.AntDir .. "/3rd/luaecs/*.c",
    msvc = {
        flags = {
            "/wd4996",
        }
    }
}
