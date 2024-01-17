local lm = require "luamake"
local fs = require "bee.filesystem"

local ROOT <const> = "../../"
local Ant3rd <const> = ROOT.."3rd/"

local fmodDir = Ant3rd .. "fmod"
local EnableLog = false

if lm.os == "windows" then
    local inputpaths =  {
        fmodDir .. "/windows/core/lib/x64/" .. (EnableLog and "fmodL.dll" or "fmod.dll"),
        fmodDir .. "/windows/studio/lib/x64/" .. (EnableLog and "fmodstudioL.dll" or "fmodstudio.dll"),
    }
    local outputpaths = {}
    for idx, d in ipairs(inputpaths) do
        outputpaths[idx] = "../../" .. lm.bindir .. "/" .. fs.path(d):filename():string()
    end
    lm:copy "copy_fmod" {
        input = inputpaths,
        output = outputpaths,
    }
end

lm:lua_source "audio" {
    includes = {
        ROOT .. "3rd/bee.lua",
        ROOT .. "clibs/luabind",
    },
    windows = {
        deps = "copy_fmod",
        sources = "src/luafmod.cpp",
        includes = {
            fmodDir.."/windows/core/inc",
            fmodDir.."/windows/studio/inc",
        },
        linkdirs ={
            fmodDir.."/windows/core/lib/x64",
            fmodDir.."/windows/studio/lib/x64",
        },
    },
    msvc = {
        links = {
            EnableLog and "fmodL_vc" or "fmod_vc",
            EnableLog and "fmodstudioL_vc" or "fmodstudio_vc"
        },
    },
    mingw = {
        links = {
            EnableLog and "fmodL" or "fmod",
            EnableLog and "fmodstudioL" or "fmodstudio"
        },
    },
    macos = {
        sources = "src/empty_luafmod.c",
    },
    ios = {
        sources = "src/luafmod.cpp",
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
        frameworks = {
            "AVFAudio",
            "AudioToolBox",
        }
    },
    android = {
        sources = "src/empty_luafmod.c",
    }
}
