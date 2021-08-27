local lm = require "luamake"

lm:source_set "fcpp" {
    rootdir = "../bgfx/3rdparty/fcpp",
    defines = {
        "NINCLUDE=64",
        "NWORK=65536",
        "NBUFF=65536",
        "OLD_PREPROCESSOR=0",
    },
    sources = {
        "*.c",
        "!usecpp.c",
    },
    msvc = {
        defines = "_CRT_SECURE_NO_WARNINGS",
    },
}

lm:source_set "glslang" {
    rootdir = "../bgfx/3rdparty/glslang",
    defines = {
        "ENABLE_OPT=1",
        "ENABLE_HLSL=1",
    },
    includes = {
        ".",
        "..",
        "../spirv-tools/include",
        "../spirv-tools/source",
    },
    sources = {
        "glslang/*.cpp",
        "!glslang/OSDependent/Windows/main.cpp",
        "!glslang/OSDependent/Web/*",
        "hlsl/*.cpp",
        "SPIRV/*.cpp",
        "OGLCompilersDLL/*.cpp",
    },
    windows = {
        sources = "!glslang/OSDependent/Unix/*cpp",
    },
    msvc = {
        flags = {
            "/wd4146",
        }
    },
    gcc = {
        flags = "-Wno-maybe-uninitialized"
    }
}

lm:source_set "glsl-optimizer" {
    rootdir = "../bgfx/3rdparty/glsl-optimizer",
    cxx = "c++14",
    includes = {
        "src",
        "include",
        "src/mesa",
        "src/mapi",
        "src/glsl",
    },
    sources = {
        "src/*.cpp",
        "src/*.c",
        "!src/node/*.cpp",
        "!src/getopt/*.c",
        "!src/glsl/main.cpp",
    },
    msvc = {
        includes = "src/glsl/msvc",
        defines = {
            "__STDC__",
            "__STDC_VERSION__=199901L",
            "strdup=_strdup",
            "_CRT_SECURE_NO_WARNINGS",
        },
        flags = {
            "/wd4819",
            "/wd4291",
            "/wd4117",
        }
    },
    gcc = {
        flags = {
            "-Wno-parentheses",
            "-Wno-unused-function",
            "-Wno-misleading-indentation"
        }
    }
}

lm:source_set "spirv-opt" {
    rootdir = "../bgfx/3rdparty/spirv-tools",
    includes = {
        ".",
        "include",
         "include/generated",
         "source",
         "../spirv-headers/include",
    },
    sources = {
        "source/*.cpp",
    },
    msvc = {
        defines = "_CRT_SECURE_NO_WARNINGS",
        flags = {
            "/wd4819",
        }
    }
}

lm:source_set "spirv-cross" {
    rootdir = "../bgfx/3rdparty/spirv-cross",
    defines  = "SPIRV_CROSS_EXCEPTIONS_TO_ASSERTIONS",
    includes = "include",
    sources = {
        "spirv_cfg.cpp",
        "spirv_cpp.cpp",
        "spirv_cross.cpp",
        "spirv_cross_parsed_ir.cpp",
        "spirv_cross_util.cpp",
        "spirv_glsl.cpp",
        "spirv_hlsl.cpp",
        "spirv_msl.cpp",
        "spirv_parser.cpp",
        "spirv_reflect.cpp",
    }
}

lm:exe "shaderc" {
    rootdir = "../bgfx",
    deps = {
        "bx",
        "fcpp",
        "glslang",
        "glsl-optimizer",
        "spirv-opt",
        "spirv-cross",
    },
    includes = {
        "../bx/include",
        "../bimg/include",
        "../bgfx/include",
        "3rdparty/webgpu/include",
         "3rdparty/dxsdk/include",
        "3rdparty/fcpp",
        "3rdparty/glslang/glslang/Public",
        "3rdparty/glslang/glslang/Include",
        "3rdparty/glslang",
        "3rdparty/glsl-optimizer/include",
        "3rdparty/glsl-optimizer/src/glsl",
        "3rdparty/spirv-cross",
        "3rdparty/spirv-tools/include",
    },
    sources = {
        "tools/shaderc/*.cpp",
        "src/vertexlayout.cpp",
        "src/shader*.cpp",
    },
    msvc = {
        defines = "_CRT_SECURE_NO_WARNINGS",
        includes = "../bx/include/compat/msvc",
        flags = {
            "/wd4819",
        }
    },
    mingw = {
        includes = "../bx/include/compat/mingw",
    }
}
