local lm = require "luamake"

if lm.mode == "debug" and lm.target == "x64" and lm.compiler == "msvc" then
    lm.ldflags = {
        "/STACK:"..0x160000
    }
end

lm:source_set "lua_source" {
    sources = {
        lm.AntDir .. "/3rd/bee.lua/3rd/lua/onelua.c",
    },
    defines = "MAKE_LIB",
    windows = {
        defines = "LUA_BUILD_AS_DLL",
    },
    linux = {
        defines = "LUA_USE_POSIX",
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
        sources = lm.AntDir .. ("/3rd/bee.lua/3rd/lua/fast_setjmp_%s.s"):format(lm.arch)
    }
}

if lm.os == "windows" then
    lm:source_set "lua_source" {
        includes = {
            lm.AntDir .. "/3rd/bee.lua/",
        },
        sources = {
            lm.AntDir .. "/3rd/bee.lua/3rd/lua/bee_utf8_crt.cpp",
        }
    }
end
