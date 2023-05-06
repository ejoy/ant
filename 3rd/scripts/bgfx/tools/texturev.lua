local lm = require "luamake"

require "examples.common"
require "utf8.support-utf8"

lm:exe "texturev" {
    rootdir = lm.BgfxDir,
    deps = {
        "example-common",
        "bimg-decode",
        "bgfx-lib",
    },
    includes = {
        lm.BxDir / "include",
        lm.BimgDir / "include",
        "include",
        "3rdparty",
        "examples/common",
    },
    sources = {
        "tools/texturev/texturev.cpp",
    },
    windows = {
        deps = "bgfx-support-utf8",
        links = {
            "comdlg32",
            "gdi32",
            "user32",
            "shell32",
        }
    },
    macos = {
        frameworks = {
            "Metal",
            "QuartzCore",
            "OpenGL",
            "Cocoa",
            "IOKit",
        }
    }
}
