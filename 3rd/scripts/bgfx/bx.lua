local lm = require "luamake"

lm:source_set "bx" {
    rootdir = "../bx/",
    defines = {
        "__STDC_FORMAT_MACROS",
        lm.mode == "debug" and "BX_CONFIG_DEBUG=1",
    },
    includes = {
        "include",
        "3rdparty"
    },
    sources = {
        "src/**.cpp",
        "!src/amalgamated.cpp",
    },
    gcc = {
        flags = "-Wno-maybe-uninitialized"
    }
}
