local lm = require "luamake"

dofile "../common.lua"

lm:source_set "source_ltask" {
    includes = LuaInclude,
    sources = Ant3rd .. "ltask/src/*.c",
    --defines = "DEBUGLOG",
    windows = {
        links = "user32",
    },
    msvc = {
        defines = "LUA_BUILD_AS_DLL",
        links = "winmm",
    },
    gcc = {
        links = "pthread",
        visibility = "default",
    },
}

lm:lua_dll "ltask" {
    deps = "source_ltask"
}
