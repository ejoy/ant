local lm = require "luamake"

lm:lua_source "quadsphere" {
    sources = {
        "cubesphere.c",
        "quadsphere.cpp"
    }
}
