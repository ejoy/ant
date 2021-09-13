local lm = require "luamake"

dofile "../common.lua"

lm:source_set "luabind" {
    includes = LuaInclude,
    sources = "luaref.cpp",
}
