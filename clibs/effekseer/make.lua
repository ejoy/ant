local lm = require "luamake"

dofile "../common.lua"

local EffekseerDir = Ant3rd .. "effekseer"

lm:source_set "source_effekseer" {
    includes = {
        EffekseerDir.."/Effekseer",
        EffekseerDir.."/EffekseerRendererBGFX",
        "../lua2struct",
        LuaInclude,
        BgfxInclude,
        Ant3rd .."glm",
    },
    sources = {
        "*.cpp",
        EffekseerDir.."/*.cpp",
    },
    msvc = {
        flags = {
            "-wd4244"
        }
    }
}

lm:lua_dll "effekseer" {
    deps = "source_effekseer",
}
