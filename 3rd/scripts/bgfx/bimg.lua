local lm = require "luamake"

lm:source_set "astc-codec" {
    rootdir = "../bimg/3rdparty/astc-codec",
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
        }
    }
}

lm:source_set "bimg" {
    rootdir = "../bimg/",
    deps = "astc-codec",
    includes = {
        "../bx/include",
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

lm:source_set "bimg_decode" {
    rootdir = "../bimg/",
    includes = {
        "../bx/include",
        "include",
        "3rdparty"
    },
    sources = {
        "src/image_decode.cpp",
    }
}

lm:source_set "bimg-iqa" {
    rootdir = "../bimg/",
    includes = "3rdparty/iqa/include",
    sources = "3rdparty/iqa/source/*.c",
}

lm:source_set "bimg_encode" {
    rootdir = "../bimg/",
    deps = {
        "astc-codec",
        "bimg-iqa",
    },
    includes = {
        "../bx/include",
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
        "3rdparty/nvtt/**.cpp",
        "3rdparty/pvrtc/*.cpp",
        "3rdparty/astc/astc_lib.cpp",
        "3rdparty/astc/astc_quantization.cpp",
        "3rdparty/astc/astc_integer_sequence.cpp",
        "3rdparty/astc/astc_weight_align.cpp",
        "3rdparty/astc/astc_symbolic_physical.cpp",
        "3rdparty/astc/astc_block_sizes2.cpp",
        "3rdparty/astc/astc_decompress_symbolic.cpp",
        "3rdparty/astc/astc_compress_symbolic.cpp",
        "3rdparty/astc/astc_imageblock.cpp",
        "3rdparty/astc/astc_partition_tables.cpp",
        "3rdparty/astc/softfloat.cpp",
        "3rdparty/astc/astc_color_unquantize.cpp",
        "3rdparty/astc/astc_weight_quant_xfer_tables.cpp",
        "3rdparty/astc/astc_compute_variance.cpp",
        "3rdparty/astc/astc_find_best_partitioning.cpp",
        "3rdparty/astc/astc_averages_and_directions.cpp",
        "3rdparty/astc/mathlib.cpp",
        "3rdparty/astc/astc_kmeans_partitioning.cpp",
        "3rdparty/astc/astc_color_quantize.cpp",
        "3rdparty/astc/astc_pick_best_endpoint_format.cpp",
        "3rdparty/astc/astc_encoding_choice_error.cpp",
        "3rdparty/astc/astc_ideal_endpoints_and_weights.cpp",
        "3rdparty/astc/astc_percentile_tables.cpp",
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
