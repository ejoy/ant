local lm = require "luamake"

dofile "../common.lua"

lm:lua_dll "subprocess" {
    sources = {
        "file_helper.cpp",
        "lsubprocess.cpp",
    },
    windows = {
        sources = "*_win.cpp",
        links = {
            "ole32",
            "user32"
        },
    },
    linux = {
        sources = "*_posix.cpp",
    },
    macos = {
        sources = "*_posix.cpp",
    }
}
