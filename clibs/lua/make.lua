local lm = require "luamake"

if lm.mode == "debug" and lm.target == "x64" and lm.compiler == "msvc" then
    lm.ldflags = {
        "/STACK:"..0x160000
    }
end

lm:source_set "lua_source" {
    sources = {
        "*.c",
        "!linit.c",
        "!lua.c",
        "!luac.c",
        "!utf8_lua.c",
    },
    windows = {
        defines = "LUA_BUILD_AS_DLL",
    },
    macos = {
        visibility = "default",
        defines = "LUA_USE_MACOSX",
        sources = {
            "!utf8_*.c"
        }
    },
    ios = {
        sources = {
            "!utf8_*.c"
        }
    }
}

lm:source_set "lua_source" {
    sources = {
        "linit.c",
    },
    defines = "ANT_LIBRARIES"
}
