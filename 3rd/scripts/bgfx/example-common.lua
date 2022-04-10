local lm = require "luamake"

lm:lib "example-common" {
    rootdir = BgfxDir,
    includes = {
        BxDir .. "include",
        BimgDir .. "include",
        "include",
        "3rdparty",
    },
    sources = {
        "3rdparty/meshoptimizer/src/**/*.cpp",
        "3rdparty/dear-imgui/**/*.cpp",
        "examples/common/**/*.cpp",
    },
    msvc = {
        defines = {
            "__STDC_FORMAT_MACROS",
        }
    },
    macos = {
        sources = {
            "examples/common/**/*.mm"
        }
    }
}
