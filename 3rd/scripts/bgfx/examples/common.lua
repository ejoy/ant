local lm = require "luamake"

lm:lib "example-common" {
    rootdir = lm.BgfxDir,
    includes = {
        lm.BxDir / "include",
        lm.BimgDir / "include",
        "include",
        "3rdparty",
    },
    sources = {
        "3rdparty/meshoptimizer/src/*.cpp",
        "3rdparty/dear-imgui/*.cpp",
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
    },
    android = {
        includes = "3rdparty/native_app_glue",
        links = {
            "android",
            "log",
            "m",
        }
    },
    gcc = {
        flags = {
            "-Wno-comment",
            "-Wno-unused-but-set-variable",
            "-Wno-sign-compare"
        }
    },
    clang = {
        flags = {
            "-Wno-comment",
            "-Wno-deprecated-declarations",
            "-Wno-unused-function"
        }
    }
}

lm:source_set "example-runtime" {
    deps = {
        "bx",
        "bimg-decode",
        "bgfx-lib",
        "example-common",
    },
    windows = {
        links = {
            "user32",
            "gdi32",
            "shell32",
            "comdlg32"
        }
    },
    linux = {
        links = {
            "X11"
        }
    },
    macos = {
        frameworks = {
            "IOKit",
            "Metal",
            "QuartzCore",
        }
    }
}
