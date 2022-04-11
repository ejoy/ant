local lm = require "luamake"
local fs = require "bee.filesystem"

dofile "../common.lua"

local fmodDir = Ant3rd .. "fmod"

local inputpaths = {
    fmodDir .. "/windows/core/lib/x64/fmodL.dll",
    fmodDir .. "/windows/studio/lib/x64/fmodstudioL.dll",
}

local outputpaths = {}

for idx, d in ipairs(inputpaths) do
    outputpaths[idx] = "../../" .. lm.bindir .. "/" .. fs.path(d):filename():string()
end

lm:copy "copy_fmod" {
    input = inputpaths,
    output = outputpaths,
}

lm:lua_source "audio" {
    sources = {
        "*.cpp",
    },
	windows = {
        includes = {
            fmodDir.."/windows/core/inc",
            fmodDir.."/windows/studio/inc",
        },
        linkdirs ={
            fmodDir.."/windows/core/lib/x64",
            fmodDir.."/windows/studio/lib/x64",
        },
        links = {
            "fmodL_vc",
            "fmodstudioL_vc"
        },
	},
    mingw = {
        includes = {
            fmodDir.."/windows/core/inc",
            fmodDir.."/windows/studio/inc",
        },
        linkdirs ={
            fmodDir.."/windows/core/lib/x64",
            fmodDir.."/windows/studio/lib/x64",
        },
        -- links = {
        --     "fmodL",
        --     "fmodstudioL"
        -- },
    },
    deps = {
        "copy_fmod",
    }
}
