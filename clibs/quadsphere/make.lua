local lm = require "luamake"

lm:lua_src "quadsphere" {
    sources = {
        "cubesphere.c",
        "quadsphere.cpp"
    }
}
