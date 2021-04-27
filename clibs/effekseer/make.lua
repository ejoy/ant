local lm = require "luamake"

local effekseerDir = "../../3rd/effekseer"

local platform = require "bee.platform"

print(lm.plat)
print(platform.OS)

lm:lua_dll "effekseer" {
    includes = {
        effekseerDir.."/Effekseer",
        effekseerDir.."/EffekseerRendererBGFX",
        "../../3rd/bgfx/include",
        "../../3rd/bx/include",
        "../../3rd/glm"
    },
    sources = {
        "*.cpp",
        effekseerDir.."/*.cpp",
    },
    flags = {
        lm.plat=="msvc" and "-wd4244"
    },
    ldflags = {
        
    }
}
