local lm = require "luamake"

dofile "../common.lua"

if lm.plat == "msvc" or lm.plat == "mingw" then
    lm:lua_dll "filedialog" {
        sources =  "filedialog.cpp",
        links = "ole32",
        mingw = {
            links = "uuid"
        }
    }
else
    lm:phony "filedialog" {}
end
