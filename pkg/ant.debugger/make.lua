local lm = require "luamake"

local ROOT <const> = "../../"

lm:lua_source "debugger" {
    defines = {
        "DBG_LUA_VERSION=504",
        "LUA_VERSION_LATEST",
    },
    includes = {
        ROOT .. "3rd/bee.lua/",
        ROOT .. "3rd/bee.lua/3rd/lua/",
        ROOT .. "3rd/bee.lua/3rd/lua-seri",
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
