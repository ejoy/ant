local lm = require "luamake"

BgfxDir = "../bgfx/"
BxDir = "../bx/"
BimgDir = "../bimg/"

require "bgfx.init"

lm:copy "copy_bgfx_shader" {
    input = {
        BgfxDir .. "src/bgfx_shader.sh",
        BgfxDir .. "src/bgfx_compute.sh",
        BgfxDir .. "examples/common/common.sh",
        BgfxDir .. "examples/common/shaderlib.sh",
    },
    output = {
        "../../packages/resources/shaders/bgfx_shader.sh",
        "../../packages/resources/shaders/bgfx_compute.sh",
        "../../packages/resources/shaders/common.sh",
        "../../packages/resources/shaders/shaderlib.sh",
    }
}
