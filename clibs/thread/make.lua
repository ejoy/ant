local lm = require "luamake"

dofile "../common.lua"

lm:source_set "source_thread" {
    includes = LuaInclude,
    sources = {
        "lthread.c",
        "lseri.c",
    }
}

lm:lua_dll "thread" {
    deps = "source_thread"
}
