local lm = require "luamake"

lm:source_set "astc-codec" {
    rootdir = lm.BimgDir / "3rdparty/astc-codec",
    includes = {
        ".",
        "include"
    },
    sources = {
        "src/decoder/*.cc",
    },
    gcc = {
        flags = {
            "-Wno-class-memaccess",
        }
    },
    clang = {
        flags = {
            "-Wno-deprecated-array-compare",
            "-Wno-unused-function",
            "-Wno-unused-const-variable"
        }
    }
}

lm:source_set "bimg" {
    rootdir = lm.BimgDir,
    deps = "astc-codec",
    includes = {
        lm.BxDir / "include",
        "include",
        "3rdparty/astc-codec/include"
    },
    sources = {
        "src/image.cpp",
        "src/image_gnf.cpp",
    },
    gcc = {
        flags = {
            "-Wno-class-memaccess",
        }
    }
}

lm:source_set "bimg-decode" {
    rootdir = lm.BimgDir,
    includes = {
        lm.BxDir / "include",
        "include",
        "3rdparty",
        "3rdparty/tinyexr/deps/miniz"
    },
    sources = {
        "src/image_decode.cpp",
        "3rdparty/tinyexr/deps/miniz/miniz.c",
    }
}

lm:source_set "bimg-iqa" {
    rootdir = lm.BimgDir,
    includes = "3rdparty/iqa/include",
    sources = "3rdparty/iqa/source/*.c",
}

lm:source_set "bimg-encode" {
    rootdir = lm.BimgDir,
    deps = {
        "astc-codec",
        "bimg-iqa",
    },
    includes = {
        lm.BxDir / "include",
        "include",
        "3rdparty",
        "3rdparty/nvtt",
        "3rdparty/iqa/include",
    },
    sources = {
        "src/image_encode.cpp",
        "src/image_cubemap_filter.cpp",
        "3rdparty/libsquish/*.cpp",
        "3rdparty/edtaa3/*.cpp",
        "3rdparty/etc1/*.cpp",
        "3rdparty/etc2/*.cpp",
        "3rdparty/nvtt/**/*.cpp",
        "3rdparty/pvrtc/*.cpp",
        "3rdparty/astc/*.cpp",
    },
    msvc = {
        flags = {
            "/wd4244",
            "/wd4819",
            "/wd5056",
        }
    },
    gcc = {
        flags = {
            "-Wno-class-memaccess",
        }
    },
    clang = {
        flags = {
            "-Wno-tautological-compare",
            "-Wno-unused-function",
        }
    }
}
