local lm = require "luamake"

if lm.os == "windows" then
    lm:copy "copy_fmod" {
        inputs = {
            lm.AntDir .. "/3rd/fmod/windows/core/lib/x64/fmod.dll",
            lm.AntDir .. "/3rd/fmod/windows/studio/lib/x64/fmodstudio.dll",
        },
        outputs = {
            "../../" .. lm.bindir .. "/fmod.dll",
            "../../" .. lm.bindir .. "/fmodstudio.dll",
        },
    }
end

lm:lua_src "audio" {
    includes = {
        lm.AntDir .. "/3rd/bee.lua",
        lm.AntDir .. "/clibs/luabind",
    },
    windows = {
        deps = "copy_fmod",
        sources = "src/luafmod.cpp",
        includes = {
            lm.AntDir .. "/3rd/fmod/windows/core/inc",
            lm.AntDir .. "/3rd/fmod/windows/studio/inc",
        },
        linkdirs ={
            lm.AntDir .. "/3rd/fmod/windows/core/lib/x64",
            lm.AntDir .. "/3rd/fmod/windows/studio/lib/x64",
        },
    },
    msvc = {
        links = {
            "fmod_vc",
            "fmodstudio_vc"
        },
    },
    mingw = {
        links = {
            "fmod",
            "fmodstudio"
        },
    },
    macos = {
        sources = "src/empty_luafmod.c",
    },
    linux = {
        sources = "src/empty_luafmod.c",
    },
    ios = {
        sources = "src/luafmod.cpp",
        includes = {
            lm.AntDir .. "/3rd/fmod/ios/core/inc",
            lm.AntDir .. "/3rd/fmod/ios/studio/inc",
        },
        linkdirs ={
            lm.AntDir .. "/3rd/fmod/ios/core/lib",
            lm.AntDir .. "/3rd/fmod/ios/studio/lib",
        },
        links = {
            "fmod_iphoneos",
            "fmodstudio_iphoneos"
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
