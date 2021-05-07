local lm = require "luamake"

dofile "../common.lua"

lm:build {
    "$luamake", "lua", "@embed.lua",
    "@../../engine/firmware/bootstrap.lua",
    "@.", "FirmwareBootstrap",
    output = "FirmwareBootstrap.h",
}

lm:build {
    "$luamake", "lua", "@embed.lua",
    "@../../engine/firmware/io.lua",
    "@.", "FirmwareIo",
    output = "FirmwareIo.h",
}

lm:build {
    "$luamake", "lua", "@embed.lua",
    "@../../engine/firmware/vfs.lua",
    "@.", "FirmwareVfs",
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
