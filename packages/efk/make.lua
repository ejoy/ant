local lm = require "luamake"

local rootdir = "../../../../"
lm.EfkDir       = rootdir .. "3rd/"
lm.BgfxDir      = lm.EfkDir .. "bgfx"
lm.BxDir        = lm.EfkDir .. "bx"
lm.BimgDir      = lm.EfkDir .. "bimg"
lm.BgfxBinDir   = lm.bindir
lm.LuaInclude   = rootdir .. "clibs/lua/"
lm:import "efkbgfx/luabinding/make.lua"

lm:source_set "source_efk" {
    includes = {
        "../../3rd/Effekseer/Dev/Cpp",
        "../../3rd/Effekseer/Dev/Cpp/Effekseer",
        "../../3rd/bgfx/include",
        "../../3rd/bx/include",
        "../../clibs/lua",
    },
    sources = {
        "lefk.cpp",
    },
    deps = {
        "source_effekseer_callback",
    },
    -- linkdirs = {
    --     lm.bindir,
    -- },
    -- links = {
    --     "efkbgfx_lib",
    -- }
}