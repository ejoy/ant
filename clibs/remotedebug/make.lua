local lm = require "luamake"

lm:source_set "remotedebug" {
    cxx = "c++17", --TODO: clang does not support c++20
    includes = {
        "../lua"
    },
    defines = {
        "RLUA_DISABLE"
    },
    sources = {
        "*.cpp",
        "thunk/*.cpp",
    },
    windows = {
        links = "user32"
    }
}
