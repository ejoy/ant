local lm = require "luamake"

lm:source_set "source_bake_example" {
    includes = {
        "../../3rd/bgfx/include",
        "../../3rd/bgfx/examples/common",
        "../../3rd/bx/include",
        "../../clibs/bake",
    },
    sources = {
        "example.cpp",
    }
}

lm:exe "bake_example" {
    deps = "source_bake_example"
}
