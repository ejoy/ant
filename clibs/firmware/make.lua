local lm = require "luamake"

dofile "../common.lua"

lm:build {
    "$luamake", "lua", "@embed.lua", "$in",
    "@.", "FirmwareBootstrap",
    input = "../../engine/firmware/bootstrap.lua",
    output = "FirmwareBootstrap.h",
}

lm:build {
    "$luamake", "lua", "@embed.lua", "$in",
    "@.", "FirmwareIo",
    input = "../../engine/firmware/io.lua",
    output = "FirmwareIo.h",
}

lm:build {
    "$luamake", "lua", "@embed.lua", "$in",
    "@.", "FirmwareVfs",
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

lm:source_set "source_firmware" {
    includes = LuaInclude,
    sources = {
        "firmware.cpp",
    }
}

lm:lua_dll "firmware" {
    deps = "source_firmware"
}
