local lm = require "luamake"

lm:copy "copy_task_lua" {
    inputs = {
        lm.AntDir .. "/3rd/ltask/service/root.lua",
        lm.AntDir .. "/3rd/ltask/lualib/service.lua",
        lm.AntDir .. "/3rd/ltask/lualib/bootstrap.lua",
        lm.AntDir .. "/3rd/ltask/service/timer.lua",
    },
    outputs = {
        lm.AntDir .. "/engine/firmware/ltask_root.lua",
        lm.AntDir .. "/engine/firmware/ltask_service.lua",
        lm.AntDir .. "/engine/firmware/ltask_bootstrap.lua",
        lm.AntDir .. "/pkg/ant.engine/service/timer.lua",
    }
}

lm:lua_src "ltask" {
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
    linux = {
        defines = {
            "_GNU_SOURCE",
        },
    },
    msvc = {
        flags = {
            "/experimental:c11atomics"
        },
    },
    gcc = {
        links = "pthread",
    },
}
