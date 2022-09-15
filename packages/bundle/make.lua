local lm = require "luamake"

lm:lua_source "bundle" {
    sources = {
        "src/bundle.c",
    }
}
