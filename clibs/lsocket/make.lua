local lm = require "luamake"

dofile "../common.lua"

lm:source_set "source_lsocket" {
    includes = LuaInclude,
    sources = {
        "lsocket.c",
    },
    windows = {
        sources = {
            "win_compat.c",
        },
        links = {
            "ws2_32"
        }
    }
}

lm:lua_dll "lsocket" {
    deps = "source_lsocket"
}
