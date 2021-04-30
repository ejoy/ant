local lm = require "luamake"

dofile "../common.lua"

lm:source_set "source_protocol" {
    includes = LuaInclude,
    sources = {
        "lprotocol.c",
    }
}

lm:lua_dll "protocol" {
    deps = "source_protocol"
}
