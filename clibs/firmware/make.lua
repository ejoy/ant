local lm = require "luamake"

lm:runlua {
    script = "embed.lua",
    args = { "$in", "$out" },
    inputs = "../../engine/firmware/bootstrap.lua",
    outputs = "FirmwareBootstrap.h",
}

lm:runlua {
    script = "embed.lua",
    args = { "$in", "$out" },
    inputs = "../../engine/firmware/io.lua",
    outputs = "FirmwareIo.h",
}

lm:runlua {
    script = "embed.lua",
    args = { "$in", "$out" },
    inputs = "../../engine/firmware/vfs.lua",
    outputs = "FirmwareVfs.h",
}

lm:runlua {
    script = "embed.lua",
    args = { "$in", "$out" },
    inputs = "../../engine/firmware/init_thread.lua",
    outputs = "FirmwareInitThread.h",
}

lm:runlua {
    script = "embed.lua",
    args = { "$in", "$out" },
    inputs = "../../engine/firmware/debugger.lua",
    outputs = "FirmwareDebugger.h",
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
