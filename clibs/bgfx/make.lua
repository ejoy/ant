local lm = require "luamake"

dofile "../common.lua"

lm:source_set "source_bgfx" {
    includes = {
        LuaInclude,
        BgfxInclude,
        "../thread",
    },
    sources = {
        "*.c",
        "bgfx_alloc.cpp"
    },
    defines = {
        lm.mode == "debug" and "BGFX_CONFIG_DEBUG",
    },
    links = {
        "bx"..lm.mode,
    },
    msvc = {
        includes = Ant3rd .. "bx/include/compat/msvc",
        linkdirs = Ant3rd .. "bgfx/.build/win64_vs2019/bin",
        flags = {
            "-wd4244",
            "-wd4267",
        }
    },
    mingw = {
        includes = Ant3rd .. "bx/include/compat/mingw",
        linkdirs = Ant3rd .. "bgfx/.build/win64_mingw-gcc/bin",
    },
    macos = {
        linkdirs = Ant3rd .. "bgfx/.build/osx-arm64/bin",
    },
}

lm:lua_dll "bgfx" {
    deps = "source_bgfx",
}
