local lm = require "luamake"

lm:lua_source "debugger" {
    defines = {
        "LUA_VERSION_LATEST",
    },
    includes = {
        lm.AntDir .. "/3rd/bee.lua/",
        lm.AntDir .. "/3rd/bee.lua/3rd/lua/",
        lm.AntDir .. "/3rd/bee.lua/3rd/lua-seri",
        "src",
    },
    sources = {
        "src/*.cpp",
        "src/luadbg/*.cpp",
        "src/symbolize/*.cpp",
        "src/thunk/*.cpp",
        "src/util/*.cpp",
        "src/compat/5x/**/*.cpp",
    },
    windows = {
        defines = {
            "_CRT_SECURE_NO_WARNINGS",
            "_WIN32_WINNT=0x0601",
            "LUA_DLL_VERSION=lu54"
        },
        links = {
            "dbghelp",
        },
    }
}
