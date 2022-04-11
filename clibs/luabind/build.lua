local lm = require "luamake"

lm:lua_source "luabind" {
    sources = "luaref.cpp",
}
