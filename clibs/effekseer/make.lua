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
    },
    defines = {
        "GLM_FORCE_QUAT_DATA_XYZW",
        "__EFFEKSEER_RENDERER_INTERNAL_LOADER__",
    },
}

lm:lua_dll "effekseer" {
    deps = "source_effekseer",
}
