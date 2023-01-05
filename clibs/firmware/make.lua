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

if lm.os == "ios" and lm.mode == "release" then
    lm:runlua {
        script = "gitlog.lua",
        args = { "$out" },
        output = "../../engine/firmware/ios_version.lua",
    }
end

lm:runlua {
    script = "embed.lua",
    args = { "$in", "$out" },
    input = "../../engine/firmware/ios_version.lua",
    output = "FirmwareIosVersion.h",
}

lm:phony {
    input = {
        "FirmwareBootstrap.h",
        "FirmwareIo.h",
        "FirmwareVfs.h",
        "FirmwareIosVersion.h",
    },
    output = "firmware.cpp",
}

lm:lua_source "firmware" {
    sources = {
        "firmware.cpp",
    }
}
