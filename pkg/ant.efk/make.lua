local lm = require "luamake"

local rootdir = "../../../../"

lm.EfkDir       = rootdir .. "3rd/"
lm.BgfxBinDir   = lm.bindir
--BgfxDir/BxDir/BimgDir have been defined in clibs/bgfx/bgfx.lua
lm:import "efkbgfx/luabinding/make.lua"
lm:import "efkbgfx/renderer/make.lua"
lm:import "efkbgfx/shaders/make.lua"

lm:lua_source "efk" {
    includes = {
        lm.AntDir .. "/3rd/Effekseer/Dev/Cpp/Effekseer",
        lm.AntDir .. "/3rd/Effekseer/Dev/Cpp/EffekseerRendererCommon",
        lm.AntDir .. "/3rd/bgfx/include",
        lm.AntDir .. "/3rd/bx/include",
        lm.AntDir .. "/3rd/bee.lua",
        lm.AntDir .. "/clibs/luabind",
        lm.AntDir .. "/pkg/ant.resource_manager/src",
    },
    sources = {
        "lefk.cpp",
    },
    deps = {
        "source_efkbgfx_lib",
        "source_effekseer_callback",
    },
}