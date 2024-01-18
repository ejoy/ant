local lm = require "luamake"

lm:copy "copy_task_lua" {
    input = {
        lm.AntDir .. "/3rd/ltask/service/root.lua",
        lm.AntDir .. "/3rd/ltask/service/timer.lua",
        lm.AntDir .. "/3rd/ltask/service/service.lua",
    },
    output = {
        lm.AntDir .. "/engine/task/service/root.lua",
        lm.AntDir .. "/engine/task/service/timer.lua",
        lm.AntDir .. "/engine/task/service/service.lua",
    }
}

lm:lua_source "ltask" {
    deps = "copy_task_lua",
    sources = {
        lm.AntDir .. "/3rd/ltask/src/*.c",
        "!" .. lm.AntDir .. "/3rd/ltask/src/main.c",
    },
    defines = {
        --"DEBUGLOG",
        "DEBUGTHREADNAME",
    },
    windows = {
        links = {
            "user32",
            "winmm",
        }
    },
    msvc = {
        flags = {
            "/experimental:c11atomics"
        },
        ldflags = {
            "-export:luaopen_ltask",
            "-export:luaopen_ltask_bootstrap",
            "-export:luaopen_ltask_exclusive",
            "-export:luaopen_ltask_root",
        },
    },
    gcc = {
        links = "pthread",
        visibility = "default",
    },
}
