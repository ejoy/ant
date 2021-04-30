local lm = require "luamake"

dofile "../common.lua"

lm:source_set "source_crypt" {
    includes = LuaInclude,
    sources = {
        "lsha1.c",
        "lua-crypt.c"
    }
}

lm:lua_dll "crypt" {
    deps = "source_crypt"
}
