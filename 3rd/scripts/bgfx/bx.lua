local lm = require "luamake"

lm:source_set "bx" {
    rootdir = "../bx/",
    defines = {
        "__STDC_FORMAT_MACROS",
        "BX_CONFIG_DEBUG=" .. (lm.mode == "debug" and 1 or 0),
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
