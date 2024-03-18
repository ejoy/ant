local lm = require "luamake"
local fs = require "bee.filesystem"

local FirmwareDir = (lm.AntDir .. "/engine/firmware/").value
local all = {}
for path in fs.pairs(FirmwareDir) do
    local output = ("embed/%s.h"):format(path:stem():string())
    all[#all+1] = output
    lm:runlua {
        script = "embed.lua",
        args = { "$in", "$out" },
        inputs = lm:path(path),
        outputs = output,
    }
end

lm:runlua {
    script = "firmware.lua",
    args = { "$in", "$out" },
    inputs = all,
    outputs = "firmware.h",
}

lm:phony {
    inputs = {
        all,
        "firmware.h"
    },
    outputs = "firmware.cpp",
}

lm:lua_source "firmware" {
    includes = {
        lm.AntDir .. "/clibs/foundation",
    },
    sources = {
        "firmware.cpp",
    }
}
