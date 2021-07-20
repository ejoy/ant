local lm = require "luamake"

dofile "../common.lua"

lm:copy "copy_ecs_lua" {
    input = Ant3rd .. "luaecs/ecs.lua",
    output = "../../packages/luaecs/ecs.lua"
}

lm:source_set "source_ecs" {
    deps = "copy_ecs_lua",
    includes = LuaInclude,
    sources = Ant3rd .. "luaecs/luaecs.c",
    windows = {
        defines = {"LUA_BUILD_AS_DLL"},
    },
    export_luaopen = "off"
}

lm:lua_dll "ecs" {
    deps = "source_ecs",
    export_luaopen = "off"
}
