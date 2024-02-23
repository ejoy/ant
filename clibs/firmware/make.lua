local lm = require "luamake"

lm:runlua {
    script = "embed.lua",
    args = { "$in", "$out" },
    input = "../../engine/firmware/bootstrap.lua",
    output = "FirmwareBootstrap.h",
}

lm:runlua {
    script = "embed.lua",
    args = { "$in", "$out" },
    input = "../../engine/firmware/io.lua",
    output = "FirmwareIo.h",
}

lm:runlua {
    script = "embed.lua",
    args = { "$in", "$out" },
    input = "../../engine/firmware/vfs.lua",
    output = "FirmwareVfs.h",
}

lm:runlua {
    script = "embed.lua",
    args = { "$in", "$out" },
    input = "../../engine/firmware/init_thread.lua",
    output = "FirmwareInitThread.h",
}

lm:runlua {
    script = "embed.lua",
    args = { "$in", "$out" },
    input = "../../engine/firmware/debugger.lua",
    output = "FirmwareDebugger.h",
}

lm:phony {
    inputs = {
        "FirmwareBootstrap.h",
        "FirmwareIo.h",
        "FirmwareVfs.h",
        "FirmwareInitThread.h",
        "FirmwareDebugger.h",
    },
    outputs = "firmware.cpp",
}

lm:lua_source "firmware" {
    sources = {
        "firmware.cpp",
    }
}
