local lm = require "luamake"

dofile "../common.lua"

lm.BgfxDir = lm:path(Ant3rd .. "bgfx/")
lm.BxDir = lm:path(Ant3rd .. "bx/")
lm.BimgDir = lm:path(Ant3rd .. "bimg/")

lm:import(Ant3rd .. "bgfx.luamake/use.lua")

local SHADER_PKG_DIR <const> = Ant3rd .. "../pkg/ant.resources/shaders/"

lm:copy "copy_bgfx_shader" {
    input = {
        lm.BgfxDir .. "/src/bgfx_shader.sh",
        lm.BgfxDir .. "/src/bgfx_compute.sh",
        lm.BgfxDir .. "/examples/common/shaderlib.sh",
    },
    output = {
        SHADER_PKG_DIR .. "bgfx_shader.sh",
        SHADER_PKG_DIR .. "bgfx_compute.sh",
        SHADER_PKG_DIR .. "shaderlib.sh",
    }
}
