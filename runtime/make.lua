local lm = require "luamake"
local fs = require "bee.filesystem"

local Backlist = {
    filedialog = true,
    filewatch = true,
    imgui = true,
    subprocess = true,
}

local RuntimeModules = {}

for path in (fs.path(lm.workdir) / "../clibs"):list_directory() do
    if fs.exists(path / "make.lua") then
        local name = path:stem():string()
        if not Backlist[name] then
            lm:import(("../clibs/%s/make.lua"):format(name))
            RuntimeModules[#RuntimeModules + 1] = "source_" .. name
        end
    end
end

lm:source_set "ant_common" {
    includes = {
        "../clibs/lua",
        "../3rd/bgfx/include",
        "../3rd/bx/include",
    },
    sources = {
        "common/modules.cpp",
        "common/runtime.cpp",
        "common/searcher.cpp",
    },
    windows = {
        sources = "common/set_current_win32.cpp"
    }
}

lm:exe "ant" {
    deps = {
        "ant_common",
        RuntimeModules
    },
    includes = {
        "../clibs/lua",
        "common"
    },
    links = {
        "bgfx"..lm.mode
    },
    windows = {
        sources = "windows/main.cpp",
        links = {
            "shlwapi",
        }
    }
}

lm:default "ant"
