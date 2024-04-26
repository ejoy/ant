local lm = require "luamake"

lm:lua_src "vfs" {
    sources = {
        "vfs.cpp",
    }
}
