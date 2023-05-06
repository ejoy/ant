local lm = require "luamake"

lm:source_set "bx" {
    rootdir = lm.BxDir,
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
        flags = {
            "-ffast-math",
            "-Wno-maybe-uninitialized",
        }
    },
    clang = {
        flags = "-ffast-math",
    },
    linux = {
        ldflags = "-pthread",
        links = {
            "m",
            "dl"
        }
    },
    macos = {
        frameworks = {
            "Cocoa"
        }
    }
}
