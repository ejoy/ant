local lm = require "luamake"

lm:source_set "foundation" {
    includes = {
        "../lua"
    },
    sources = {
        "vla.c"
    }
}