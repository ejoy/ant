local lm = require "luamake"

dofile "../common.lua"

lm:source_set "source_filedialog" {
    includes = {
        LuaInclude,
    },
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

lm:lua_dll "filedialog" {
    deps = "source_filedialog"
}
