local lm = require "luamake"
require "bgfx.example-common"

lm:exe "texturev" {
    rootdir = "../bgfx/",
    deps = {
        "example-common",
        "bimg_decode",
        "bimg_encode",
        "bgfx-lib",
        "bimg",
        "bx",
    },
    includes = {
        "../bx/include",
        "../bimg/include",
        "include",
        "3rdparty/iqa/include",
        "3rdparty",
        "examples/common",
    },
    sources = {
        "tools/texturev/texturev.cpp",
    },
    windows = {
        sources = "../scripts/bgfx/texturev.rc",
        links = {
            "DelayImp",
            "comdlg32",
            "gdi32",
            "psapi",
            "user32",
            "Shell32",
        }
    },
    msvc = {
        defines = "_CRT_SECURE_NO_WARNINGS",
        includes = "../bx/include/compat/msvc",
    },
    mingw = {
        includes = "../bx/include/compat/mingw",
    },
    -- macos = {
    --     includes = "../bx/include/compat/osx",
    --     frameworks = {
    --         "Cocoa"
    --     }
    -- }
}
