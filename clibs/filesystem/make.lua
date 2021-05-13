local lm = require "luamake"

dofile "../common.lua"

lm:source_set "source_filesystem" {
    includes = LuaInclude,
    sources = {
        "error.cpp",
        "file_helper.cpp",
        "path_helper.cpp",
        "lua_filesystem.cpp"
    },
    windows = {
        sources = {
            "unicode.cpp",
            "windows_category.cpp",
        },
    }
}

lm:lua_dll "filesystem" {
    deps = "source_filesystem",
    msvc = {
        export_luaopen = "off",
        ldflags = {
            "-export:luaopen_filesystem_cpp"
        }
    }
}
