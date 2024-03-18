local lm = require "luamake"

lm:lua_source "fastio_runtime" {
    defines = {
        "__ANT_RUNTIME__"
    },
    includes = {
        lm.AntDir .. "/clibs/foundation",
    },
    sources = {
        "fastio.cpp",
        "sha1.c",
    },
}

lm:lua_source "fastio_editor" {
    includes = {
        lm.AntDir .. "/clibs/foundation",
    },
    sources = {
        "fastio.cpp",
        "sha1.c",
    },
}
