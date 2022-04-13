local lm = require "luamake"

lm:source_set "astc-codec" {
    rootdir = BimgDir .. "3rdparty/astc-codec",
    includes = {
        ".",
        "include"
    },
    sources = {
        "src/decoder/astc_file.cc",
        "src/decoder/codec.cc",
        "src/decoder/endpoint_codec.cc",
        "src/decoder/footprint.cc",
        "src/decoder/integer_sequence_codec.cc",
        "src/decoder/intermediate_astc_block.cc",
        "src/decoder/logical_astc_block.cc",
        "src/decoder/partition.cc",
        "src/decoder/physical_astc_block.cc",
        "src/decoder/quantization.cc",
        "src/decoder/weight_infill.cc",
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
    rootdir = BimgDir,
    deps = "astc-codec",
    includes = {
        BxDir .. "include",
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
    },
    clang = {
        flags = {
            "-Wno-unused-but-set-variable",
        }
    }
}

lm:source_set "bimg_decode" {
    rootdir = BimgDir,
    includes = {
        BxDir .. "include",
        "include",
        "3rdparty",
        "3rdparty/tinyexr/deps/miniz"
    },
    sources = {
        "src/image_decode.cpp",
        "3rdparty/tinyexr/deps/miniz/miniz.c",
    },
    clang = {
        flags = {
            "-Wno-unused-but-set-variable",
        }
    }
}

lm:source_set "bimg-iqa" {
    rootdir = BimgDir,
    includes = "3rdparty/iqa/include",
    sources = "3rdparty/iqa/source/*.c",
}

lm:source_set "bimg_encode" {
    rootdir = BimgDir,
    deps = {
        "astc-codec",
        "bimg-iqa",
    },
    includes = {
        BxDir .. "include",
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
