local lm = require "luamake"
local platform = require "bee.platform"

local ZLIBDIR = lm.AntDir.."/3rd/zlib-ng"
local MINIZIPDIR = lm.AntDir.."/3rd/minizip-ng"

local function macos_support_arm64()
    -- 这意味着luamake的arch是arm64，说明当前macos可以运行arm64，所以我们把ant也编译为arm64，否则编译为x86_64。
    -- 理论上我们可以用x86_64的luamake编译arm64的ant，比如在CI里。但目前我们不需要这样做。
    return platform.Arch == "arm64"
end

lm:runlua "gen-zconf" {
    script = "configure_file.lua",
    args = { "$in", "$out" },
    inputs = ZLIBDIR.."/zconf-ng.h.in",
    outputs = "$builddir/gen-zlib/zconf-ng.h",
}

lm:runlua "gen-zlib" {
    script = "configure_file.lua",
    args = { "$in", "$out" },
    inputs = ZLIBDIR.."/zlib-ng.h.in",
    outputs = "$builddir/gen-zlib/zlib-ng.h",
}

lm:runlua "gen-zlib_name_mangling" {
    script = "configure_file.lua",
    args = { "$in", "$out" },
    inputs = ZLIBDIR.."/zlib_name_mangling.h.empty",
    outputs = "$builddir/gen-zlib/zlib_name_mangling-ng.h",
}

lm:source_set "zlib-ng-x86-simd" {
    objdeps = {
        "gen-zconf",
        "gen-zlib",
        "gen-zlib_name_mangling",
    },
    includes = {
        ZLIBDIR,
        ZLIBDIR.."/arch/x86/",
        "$builddir/gen-zlib",
    },
    sources = {
        ZLIBDIR.."/functable.c",
    },
    defines = {
        "DISABLE_RUNTIME_CPU_DETECTION",
        "X86_FEATURES",
    },
    msvc = {
        sources = {
            ZLIBDIR.."/arch/x86/*.c",
        },
        defines = {
            "X86_AVX2",
            "X86_SSE42",
            "X86_SSSE3",
            "X86_SSE2",
            "X86_PCLMULQDQ_CRC",
            --"X86_AVX512",
            --"X86_AVX512VNNI",
            --"X86_VPCLMULQDQ_CRC",
        }
    },
}

lm:source_set "zlib-ng-x86" {
    objdeps = {
        "gen-zconf",
        "gen-zlib",
        "gen-zlib_name_mangling",
    },
    includes = {
        ZLIBDIR,
        ZLIBDIR.."/arch/x86/",
        "$builddir/gen-zlib",
    },
    sources = {
        ZLIBDIR.."/functable.c",
        ZLIBDIR.."/arch/x86/x86_features.c",
    },
    defines = {
        "DISABLE_RUNTIME_CPU_DETECTION",
        "X86_FEATURES",
    },
    gcc = {
        defines = {
            "HAVE_ATTRIBUTE_ALIGNED",
        },
    },
}

lm:source_set "zlib-ng-arm" {
    objdeps = {
        "gen-zconf",
        "gen-zlib",
        "gen-zlib_name_mangling",
    },
    includes = {
        ZLIBDIR,
        ZLIBDIR.."/arch/arm/",
        "$builddir/gen-zlib",
    },
    sources = {
        ZLIBDIR.."/functable.c",
        ZLIBDIR.."/arch/arm/*.c",
    },
    defines = {
        "DISABLE_RUNTIME_CPU_DETECTION",
        "HAVE_ARM_ACLE_H",
        "ARM_FEATURES",
        "ARM_NEON",
        "ARM_NEON_HASLD4",
    },
    gcc = {
        defines = {
            "HAVE_ATTRIBUTE_ALIGNED",
            "HAVE_BUILTIN_CTZLL",
        },
    },
    clang = {
        defines = {
            "HAVE_ATTRIBUTE_ALIGNED",
            "HAVE_BUILTIN_CTZLL",
        },
    },
}

lm:source_set "zlib-ng" {
    objdeps = {
        "gen-zconf",
        "gen-zlib",
        "gen-zlib_name_mangling",
    },
    includes = {
        ZLIBDIR,
        "$builddir/gen-zlib"
    },
    sources = {
        ZLIBDIR.."/*.c",
        ZLIBDIR.."/arch/generic/*.c",
        "!"..ZLIBDIR.."/gz*.c",
        "!"..ZLIBDIR.."/functable.c",
        "!"..ZLIBDIR.."/cpu_features.c",
    },
    defines = {
        "DISABLE_RUNTIME_CPU_DETECTION",
    },
    linux = {
        deps = "zlib-ng-x86",
    },
    macos = {
        deps = macos_support_arm64() and "zlib-ng-arm" or "zlib-ng-x86",
    },
    ios = {
        deps = "zlib-ng-arm",
    },
    msvc = {
        deps = {
            lm.cc == "clang-cl"
                and "zlib-ng-x86"
                or "zlib-ng-x86-simd",
        },
        defines = {
            "_CRT_SECURE_NO_DEPRECATE",
            "_CRT_NONSTDC_NO_DEPRECATE",
        }
    },
    mingw = {
        deps = "zlib-ng-x86",
    },
    gcc = {
        defines = {
            "HAVE_ATTRIBUTE_ALIGNED",
            "HAVE_BUILTIN_CTZ",
            "HAVE_BUILTIN_CTZLL",
        },
    },
    clang = {
        defines = {
            "HAVE_ATTRIBUTE_ALIGNED",
            "HAVE_BUILTIN_CTZ",
            "HAVE_BUILTIN_CTZLL",
        },
    },
}

lm:source_set "minizip-ng" {
    objdeps = {
        "gen-zconf",
        "gen-zlib",
        "gen-zlib_name_mangling",
    },
    defines = {
        "MZ_ZIP_NO_CRYPTO",
		"HAVE_ZLIB",
    },
    includes = {
        MINIZIPDIR,
        ZLIBDIR,
        "$builddir/gen-zlib",
    },
    sources = {
        MINIZIPDIR.."/mz_compat.c",
        MINIZIPDIR.."/mz_os.c",
        MINIZIPDIR.."/mz_crypt.c",
        MINIZIPDIR.."/mz_strm.c",
        MINIZIPDIR.."/mz_zip.c",
        MINIZIPDIR.."/mz_zip_rw.c",
        MINIZIPDIR.."/mz_strm_buf.c",
        MINIZIPDIR.."/mz_strm_mem.c",
        MINIZIPDIR.."/mz_strm_split.c",
        MINIZIPDIR.."/mz_strm_zlib.c",
    },
    windows = {
        sources = {
            MINIZIPDIR.."/mz_os_win32.c",
            MINIZIPDIR.."/mz_strm_os_win32.c",
        },
    },
    linux = {
        defines = {
            "_GNU_SOURCE",
        },
        sources = {
            MINIZIPDIR.."/mz_os_posix.c",
            MINIZIPDIR.."/mz_strm_os_posix.c",
        },
    },
    macos = {
        sources = {
            MINIZIPDIR.."/mz_os_posix.c",
            MINIZIPDIR.."/mz_strm_os_posix.c",
        },
    },
    ios = {
        sources = {
            MINIZIPDIR.."/mz_os_posix.c",
            MINIZIPDIR.."/mz_strm_os_posix.c",
        },
    },
    msvc = {
        defines = {
            "_CRT_SECURE_NO_WARNINGS"
        },
    },
}

lm:lua_src "zip-binding" {
    objdeps = {
        "gen-zconf",
        "gen-zlib",
        "gen-zlib_name_mangling",
    },
    includes = {
        lm.AntDir .. "/3rd/minizip-ng",
        lm.AntDir .. "/3rd/bee.lua",
        lm.AntDir .. "/clibs/foundation",
        ZLIBDIR,
        "$builddir/gen-zlib",
    },
    sources = "*.c",
}

lm:lua_src "zip" {
    deps = {
        "zlib-ng",
        "minizip-ng",
        "zip-binding",
    }
}
