local lm = require "luamake"

dofile "../common.lua"

if lm.os == "windows" then
    lm:lua_dll "filedialog" {
        sources =  "filedialog.cpp",
        links = {
            "ole32",
            "uuid",
        }
    }
else
    lm:phony "filedialog" {}
end
