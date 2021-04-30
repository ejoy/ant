local lm = require "luamake"

dofile "../common.lua"

lm:lua_dll "filewatch" {
    sources = {
        "lfilewatch.cpp",
    },
    windows = {
        sources =  {
            "unicode.cpp",
            "fsevent_win.cpp",
        }
    },
    macos = {
        sources = "fsevent_osx.cpp",
    }
}