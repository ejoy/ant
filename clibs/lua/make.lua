local lm = require "luamake"

if lm.mode == "debug" and lm.target == "x64" and lm.compiler == "msvc" then
    lm.ldflags = {
        "/STACK:"..0x160000
    }
end

lm:source_set "lua_source" {
    sources = "onelua.c",
    defines = "MAKE_LIB",
    windows = {
        defines = "LUA_BUILD_AS_DLL",
    },
    macos = {
        visibility = "default",
        defines = "LUA_USE_MACOSX",
    }
}

lm:source_set "lua_source" {
    sources = {
        "utf8_crt.c",
    }
}

lm:source_set "lua_source" {
    sources = "linit.c",
    defines = "ANT_LIBRARIES"
}
