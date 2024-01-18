local lm = require "luamake"

if lm.mode == "debug" and lm.target == "x64" and lm.compiler == "msvc" then
    lm.ldflags = {
        "/STACK:"..0x160000
    }
end
lm.rootdir = lm.AntDir .. "/3rd/bee.lua/3rd/lua/"

lm:source_set "lua_source" {
    sources = "onelua.c",
    defines = "MAKE_LIB",
    windows = {
        defines = "LUA_BUILD_AS_DLL",
    },
    macos = {
        visibility = "default",
        defines = "LUA_USE_MACOSX",
    },
    ios = {
        defines = "LUA_USE_IOS",
    },
    android = {
        defines = "LUA_USE_LINUX",
    },
    msvc = {
        sources = ("fast_setjmp_%s.s"):format(lm.arch)
    }
}

if lm.os == "windows" then
    lm:source_set "lua_source" {
        sources = {
            "utf8_crt.c",
        }
    }
end
