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

lm:phony {
    input = {
        "FirmwareBootstrap.h",
        "FirmwareIo.h",
        "FirmwareVfs.h",
    },
    output = "firmware.cpp",
}

lm:lua_source "firmware" {
    sources = {
        "firmware.cpp",
    }
}
