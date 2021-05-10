local lm = require "luamake"

dofile "../common.lua"

lm:source_set "source_platform" {
    includes = {
        LuaInclude,
        BgfxInclude,
    },
    sources = {
        "lplatform.cpp",
        "platform_timer.cpp",
    },
    windows = {
        sources = {
            "platform_mingw.cpp",
            "win32/wmi.cpp"
        },
        links = {
            "gdi32",
            "user32",
            "ole32",
            "oleaut32",
            "wbemuuid",
        },
    },
    macos = {
        sources = {
            "platform_osx.mm",
            "osx/font_info.mm",
            "osx/task_info.mm",
        },
    }
}

lm:lua_dll "platform" {
    deps = "source_platform",
    msvc = {
        ldflags = "-export:luaopen_platform_timer"
    }
}
