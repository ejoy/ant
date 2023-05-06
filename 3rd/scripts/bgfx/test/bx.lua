local lm = require "luamake"

require "core.bx"

lm:exe "bx_test" {
    rootdir = lm.BxDir,
    deps = "bx",
    sources = {
        "3rdparty/catch/catch_amalgamated.cpp",
        "tests/*_test.cpp",
    },
    includes = {
        "3rdparty",
        "include",
    },
    defines = {
        "__STDC_FORMAT_MACROS",
        "CATCH_AMALGAMATED_CUSTOM_MAIN"
    },
    gcc = {
        flags = {
            "-ffast-math",
            "-Wno-maybe-uninitialized",
        }
    },
    clang = {
        flags = "-ffast-math",
    }
}

lm:exe "bx_bench" {
    rootdir = lm.BxDir,
    deps = "bx",
    sources = {
        "3rdparty/catch/catch_amalgamated.cpp",
        "tests/*_bench.cpp",
    },
    includes = {
        "3rdparty",
        "include",
    },
    defines = {
        "__STDC_FORMAT_MACROS",
        "CATCH_AMALGAMATED_CUSTOM_MAIN"
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
}
