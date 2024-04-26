local lm = require "luamake"

lm:copy "copy_ecs_lua" {
    inputs = lm.AntDir .. "/3rd/luaecs/ecs.lua",
    outputs = lm.AntDir .. "/pkg/ant.luaecs/ecs.lua"
}

lm:lua_src "ecs" {
    deps = "copy_ecs_lua",
    sources = lm.AntDir .. "/3rd/luaecs/*.c",
    msvc = {
        flags = {
            "/wd4996",
        }
    }
}
