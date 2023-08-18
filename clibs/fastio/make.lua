local lm = require "luamake"

lm:lua_source "fastio_runtime" {
    defines = {
        "__ANT_RUNTIME__"
    },
    sources = {
        "fastio.cpp",
    },
}

lm:lua_source "fastio_editor" {
    defines = {
    },
    sources = {
        "fastio.cpp",
    },
}
