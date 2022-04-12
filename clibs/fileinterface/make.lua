local lm = require "luamake"

dofile "../common.lua"

local source_name = lm.fileinterface_dynamic_lib and "source_fileinterface" or "fileinterface"
lm:lua_source (source_name) {
    defines = {
        lm.test and "FILE_INTERFACE_TEST" or "",
    },
    sources = {
        "fileinterface.c",
    },
}

if lm.fileinterface_dynamic_lib then
    lm:lua_dll "fileinterface" {
        deps = source_name,
        msvc = lm.test and {
            ldflags = {
                "-export:luaopen_fileinterface_test"
            }
        } or nil,
    }
end
