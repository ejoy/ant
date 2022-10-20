local lm = require "luamake"

local rootdir = "../../../../"
lm.EfkDir       = rootdir .. "3rd/"
lm.BgfxDir      = lm.EfkDir .. "bgfx"
lm.BxDir        = lm.EfkDir .. "bx"
lm.BimgDir      = lm.EfkDir .. "bimg"
lm.BgfxBinDir   = lm.bindir
lm.LuaInclude   = rootdir .. "3rd/bee.lua/3rd/lua/"
lm:import "efkbgfx/luabinding/make.lua"
lm:import "efkbgfx/renderer/make.lua"
lm:import "efkbgfx/shaders/make.lua"

lm:lua_source "efk" {
    includes = {
        "../../3rd/Effekseer/Dev/Cpp",
        "../../3rd/Effekseer/Dev/Cpp/Effekseer",
        "../../3rd/bgfx/include",
        "../../3rd/bx/include",
        "../../3rd/bee.lua/3rd/lua",
        "../../packages/bundle/src",
    },
    sources = {
        "lefk.cpp",
    },
    deps = {
        "source_efkbgfx_lib",
        "source_effekseer_callback",
    },
}