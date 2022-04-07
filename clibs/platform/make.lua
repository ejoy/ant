local lm = require "luamake"

dofile "../common.lua"

lm:lua_source "platform" {
    includes = {
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
        frameworks = {
            "AppKit"
        }
    },
    ios = {
        sources = {
            "platform_ios.mm",
            "osx/font_info.mm",
            "osx/task_info.mm",
            "ios/setting.mm",
            "ios/NetReachability.m",
        }
    }
}
