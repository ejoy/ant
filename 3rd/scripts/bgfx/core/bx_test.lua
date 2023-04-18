local lm = require "luamake"

local BXDIR = "../../3rd/bx/"
lm:exe "test_bx" {
    sources = {
		BXDIR .. "3rdparty/catch/catch_amalgamated.cpp",
		BXDIR .. "tests/*_test.cpp",
        BXDIR .. "src/*.cpp",
        "!" .. BXDIR .. "src/amalgamated.cpp"
    },
    includes = {
        BXDIR .. "3rdparty",
        BXDIR .. "include",
    },
    defines = {
        "BX_CONFIG_DEBUG=1",
        "CATCH_AMALGAMATED_CUSTOM_MAIN"
    },
    macos = {
        includes = {
            BXDIR .. "include/compat/osx",
        },
        frameworks = {
            "Cocoa",
        }
    },
    cxx = "c++17",
}
