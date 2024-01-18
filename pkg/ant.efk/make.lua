local lm = require "luamake"

local rootdir = "../../../../"

lm.EfkDir       = rootdir .. "3rd/"
lm.BgfxBinDir   = lm.bindir
--BgfxDir/BxDir/BimgDir have been defined in clibs/bgfx/bgfx.lua
lm:import "efkbgfx/luabinding/make.lua"
lm:import "efkbgfx/renderer/make.lua"
lm:import "efkbgfx/shaders/make.lua"

local ROOT <const> = "../../"

lm:lua_source "efk" {
    includes = {
        ROOT .. "3rd/Effekseer/Dev/Cpp",
        ROOT .. "3rd/Effekseer/Dev/Cpp/Effekseer",
        ROOT .. "3rd/bgfx/include",
        ROOT .. "3rd/bx/include",
        ROOT .. "3rd/bee.lua",
        ROOT .. "clibs/luabind",
        ROOT .. "pkg/ant.resource_manager/src",
    },
    sources = {
        "lefk.cpp",
    },
    deps = {
        "source_efkbgfx_lib",
        "source_effekseer_callback",
    },
}