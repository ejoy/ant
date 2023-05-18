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

local EnableLog = false

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
            EnableLog and "fmodL_vc" or "fmod_vc",
            EnableLog and "fmodstudioL_vc" or "fmodstudio_vc"
        },
	},
    macos = {
        includes = {
            fmodDir.."/macos/core/inc",
            fmodDir.."/macos/studio/inc",
        },
        linkdirs ={
            fmodDir.."/macos/core/lib",
            fmodDir.."/macos/studio/lib",
        },
        links = {
            EnableLog and "fmodL" or "fmod",
            EnableLog and "fmodstudioL" or "fmodstudio"
        },
    },
    ios = {
        includes = {
            fmodDir.."/ios/core/inc",
            fmodDir.."/ios/studio/inc",
        },
        linkdirs ={
            fmodDir.."/ios/core/lib",
            fmodDir.."/ios/studio/lib",
        },
        links = {
            EnableLog and "fmodL_iphoneos" or "fmod_iphoneos",
            EnableLog and "fmodstudioL_iphoneos" or "fmodstudio_iphoneos"
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
