local lm = require "luamake"

lm:lua_source "bundle" {
    sources = {
        "src/bundle.c",
    }
}

lm:lua_source "textureman" {
    sources = {
        "src/textureman.c",
    }
}
