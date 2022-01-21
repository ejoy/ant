local lm = require "luamake"

dofile "../common.lua"

if lm.os == "ios" then
    lm:phony "source_filedialog" {
    }
    return
end
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
