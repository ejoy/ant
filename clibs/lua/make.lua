local lm = require "luamake"

if lm.mode == "debug" and lm.target == "x64" and lm.compiler == "msvc" then
    lm.ldflags = {
        "/STACK:"..0x160000
    }
end

lm:source_set "source_lua" {
    sources = {
        "*.c",
        "!lua.c",
        "!luac.c",
        "!utf8_lua.c",
    },
    macos = {
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

if lm.os == "windows" then
    lm:dll "lua54" {
        sources = {
            "*.c",
            "!lua.c",
            "!luac.c",
            "!utf8_lua.c",
        },
        defines = "LUA_BUILD_AS_DLL",
    }
    lm:exe "lua" {
        deps = "lua54",
        sources = {
            "utf8_lua.c",
            "utf8_crt.c",
            "utf8_unicode.c",
        }
    }
else
    lm:exe "lua" {
        deps = "source_lua",
        sources = {
            "lua.c",
        }
    }
end


lm:exe "luac" {
    deps = "source_lua",
    sources = {
        "luac.c",
    }
}
