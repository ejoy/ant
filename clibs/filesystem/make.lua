local lm = require "luamake"

dofile "../common.lua"

lm:source_set "source_filesystem" {
    includes = LuaInclude,
    sources = {
        "*.cpp",
    }
}

lm:lua_dll "filesystem" {
    deps = "source_filesystem",
    msvc = {
        export_luaopen = false,
        ldflags = {
            "-export:luaopen_filesystem_cpp"
        }
    }
}
