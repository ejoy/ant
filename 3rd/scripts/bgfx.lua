local lm = require "luamake"

lm.BgfxDir = lm:path "../bgfx/"
lm.BxDir = lm:path "../bx/"
lm.BimgDir = lm:path "../bimg/"

lm:import "bgfx"

local SHADER_PKG_DIR<const> = "../../packages/resources/shaders/"
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
