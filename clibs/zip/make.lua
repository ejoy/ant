local lm = require "luamake"

dofile "../common.lua"

local ZLIBDIR = Ant3rd .. "zlib-ng/"
local MINIZIPDIR = Ant3rd .. "minizip-ng/"

lm:runlua "gen-zconf" {
    script = "configure_file.lua",
    args = { "$in", "$out" },
    input = ZLIBDIR.."zconf-ng.h.in",
    output = "$builddir/gen-zlib/zconf-ng.h",
}

lm:runlua "gen-zlib" {
    script = "configure_file.lua",
    args = { "$in", "$out" },
    input = ZLIBDIR.."zlib-ng.h.in",
    output = "$builddir/gen-zlib/zlib-ng.h",
}

lm:runlua "gen-zlib_name_mangling" {
    script = "configure_file.lua",
    args = { "$in", "$out" },
    input = ZLIBDIR.."zlib_name_mangling.h.empty",
    output = "$builddir/gen-zlib/zlib_name_mangling-ng.h",
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
        ZLIBDIR.."*.c",
        "!"..ZLIBDIR.."gz*.c",
    },
    msvc = {
        defines = {
            "_CRT_SECURE_NO_DEPRECATE",
            "_CRT_NONSTDC_NO_DEPRECATE",
        }
    },
    gcc = {
        defines = {
            "HAVE_THREAD_LOCAL",
            "HAVE_ATTRIBUTE_ALIGNED",
            "HAVE_BUILTIN_CTZ",
            "HAVE_BUILTIN_CTZLL",
        },
    },
    clang = {
        defines = {
            "HAVE_THREAD_LOCAL",
            "HAVE_ATTRIBUTE_ALIGNED",
            "HAVE_BUILTIN_CTZ",
            "HAVE_BUILTIN_CTZLL",
        },
    },
}

lm:source_set "minizip-ng" {
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
        MINIZIPDIR.."mz_compat.c",
        MINIZIPDIR.."mz_os.c",
        MINIZIPDIR.."mz_crypt.c",
        MINIZIPDIR.."mz_strm.c",
        MINIZIPDIR.."mz_zip.c",
        MINIZIPDIR.."mz_zip_rw.c",
        MINIZIPDIR.."mz_strm_buf.c",
        MINIZIPDIR.."mz_strm_mem.c",
        MINIZIPDIR.."mz_strm_split.c",
        MINIZIPDIR.."mz_strm_zlib.c",
    },
    windows = {
        sources = {
            MINIZIPDIR.."mz_os_win32.c",
            MINIZIPDIR.."mz_strm_os_win32.c",
        },
    },
    msvc = {
        defines = {
            "_CRT_SECURE_NO_WARNINGS"
        },
    },
}

lm:lua_source "zip-binding" {
	includes = {
		Ant3rd .. "minizip-ng",
		ZLIBDIR,
        "$builddir/gen-zlib",
	},
	sources = "*.c",
}

lm:lua_source "zip" {
	deps = {
		"zlib-ng",
		"minizip-ng",
		"zip-binding",
	}
}
