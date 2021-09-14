local lm = require "luamake"

dofile "../common.lua"

lm:lua_dll "filedialog" {
    windows = {
        sources =  "filedialog.cpp",
        links = {
            "ole32",
            "uuid",
        }
    },
    macos = {
        sources =  "filedialog.mm",
    }
}
