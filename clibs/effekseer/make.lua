local lm = require "luamake"

dofile "../common.lua"

local EffekseerDir = Ant3rd .. "effekseer"

lm:lua_source "effekseer" {
    includes = {
        EffekseerDir.."/Effekseer",
        EffekseerDir.."/EffekseerRendererBGFX",
        "../luabind",
        BgfxInclude,
        Ant3rd .."glm",
    },
    sources = {
        "*.cpp",
        EffekseerDir.."/**.cpp",
    },
    msvc = {
        flags = {
            "-wd4244"
        }
    },
	windows = {
		links = "ws2_32"
	},
    defines = {
        "GLM_FORCE_QUAT_DATA_XYZW",
    },
}
