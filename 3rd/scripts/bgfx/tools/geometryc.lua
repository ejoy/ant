local lm = require "luamake"

require "utf8.support-utf8"

lm:exe "geometryc" {
    rootdir = lm.BgfxDir,
    deps = {
        "bx",
    },
    includes = {
        lm.BxDir / "include",
        "include",
        "3rdparty",
    },
    sources = {
        "tools/geometryc/*.cpp",
        "src/vertexlayout.cpp",
        "3rdparty/meshoptimizer/src/*.cpp",
    },
    windows = {
        deps = "bgfx-support-utf8",
    }
}
