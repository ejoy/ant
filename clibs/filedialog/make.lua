local lm = require "luamake"

dofile "../common.lua"

lm:lua_dll "filedialog" {
    sources =  "filedialog.cpp",
    links = "ole32",
    mingw = {
        links = "uuid"
    }
}
