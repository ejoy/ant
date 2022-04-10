local lm = require "luamake"

require "bgfx.example-common"

lm:exe "texturev" {
    rootdir = BgfxDir,
    deps = {
        "example-common",
        "bimg_decode",
        "bimg_encode",
        "bgfx-lib",
        "bimg",
        "bx",
    },
    includes = {
        BxDir .. "include",
        BimgDir .. "include",
        "include",
        "3rdparty/iqa/include",
        "3rdparty",
        "examples/common",
    },
    sources = {
        "tools/texturev/texturev.cpp",
    },
    windows = {
        deps = "bgfx-support-utf8",
        links = {
            "DelayImp",
            "comdlg32",
            "gdi32",
            "psapi",
            "user32",
            "Shell32",
        }
    },
    macos = {
        frameworks = {
            "Cocoa",
            "Metal",
            "QuartzCore",
            "OpenGL"
        }
    }
}
