local lm = require "luamake"

if lm.mode == "debug" and lm.target == "x64" and lm.compiler == "msvc" then
    lm.ldflags = {
        "/STACK:"..0x160000
    }
end

lm:source_set "source_lua_noopenlibs" {
    sources = {
        "*.c",
        "!linit.c",
        "!lua.c",
        "!luac.c",
        "!utf8_lua.c",
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

lm:source_set "source_lua" {
    deps = {
        "source_lua_noopenlibs",
    },
    sources = {
        "linit.c",
    },
    defines = "ANT_LIBRARIES"
}

lm:source_set "source_lua_editor" {
    deps = {
        "source_lua_noopenlibs",
    },
    sources = {
        "linit.c",
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
        }
    }
else
    lm:exe "lua" {
        deps = "source_lua_editor",
        sources = {
            "lua.c",
        }
    }
end


lm:exe "luac" {
    deps = "source_lua_editor",
    sources = {
        "luac.c",
    }
}
