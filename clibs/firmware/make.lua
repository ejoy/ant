local lm = require "luamake"

lm:rule "firmware_embed" {
    "$luamake", "lua", "@embed.lua", "$in", "$out",
    description = "Firmware Embed $in",
}

lm:build {
    rule = "firmware_embed",
    input = "../../engine/firmware/bootstrap.lua",
    output = "FirmwareBootstrap.h",
}

lm:build {
    rule = "firmware_embed",
    input = "../../engine/firmware/io.lua",
    output = "FirmwareIo.h",
}

lm:build {
    rule = "firmware_embed",
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
