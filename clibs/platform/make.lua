local lm = require "luamake"

dofile "../common.lua"

lm:source_set "source_platform" {
    includes = {
        LuaInclude,
        BgfxInclude,
    },
    sources = {
        "lplatform.cpp",
        "platform_mingw.cpp",
        "platform_timer.cpp",
        "win32/wmi.cpp"
    },
    links = {
        "gdi32",
        "user32",
        "ole32",
        "oleaut32",
        "wbemuuid",
    }
}

lm:lua_dll "platform" {
    deps = "source_platform",
    msvc = {
        ldflags = "-export:luaopen_platform_timer"
    }
}
