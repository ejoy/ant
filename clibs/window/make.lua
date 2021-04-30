local lm = require "luamake"

dofile "../common.lua"

lm:source_set "source_window" {
    includes = LuaInclude,
    sources = {
        "window.c",
        "mingw/mingw_window.c",
    },
    links = {
        "user32",
        "shell32",
    }
}

lm:lua_dll "window" {
    deps = "source_window"
}
