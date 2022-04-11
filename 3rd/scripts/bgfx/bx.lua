local lm = require "luamake"

lm:source_set "bx" {
    rootdir = BxDir,
    defines = {
        "__STDC_FORMAT_MACROS",
    },
    includes = {
        "include",
        "3rdparty"
    },
    sources = {
        "src/**/*.cpp",
        "!src/amalgamated.cpp",
    },
    gcc = {
        flags = "-Wno-maybe-uninitialized"
    }
}
