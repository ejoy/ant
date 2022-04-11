local lm = require "luamake"

lm:lua_source "vfs" {
    sources = {
        "vfs.cpp",
    }
}
