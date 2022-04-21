local lm = require "luamake"

lm.BgfxDir = lm:path "../bgfx/"
lm.BxDir = lm:path "../bx/"
lm.BimgDir = lm:path "../bimg/"

lm:import "bgfx"

lm:copy "copy_bgfx_shader" {
    input = {
        lm.BgfxDir .. "src/bgfx_shader.sh",
        lm.BgfxDir .. "src/bgfx_compute.sh",
        lm.BgfxDir .. "examples/common/common.sh",
        lm.BgfxDir .. "examples/common/shaderlib.sh",
    },
    output = {
        "../../packages/resources/shaders/bgfx_shader.sh",
        "../../packages/resources/shaders/bgfx_compute.sh",
        "../../packages/resources/shaders/common.sh",
        "../../packages/resources/shaders/shaderlib.sh",
    }
}
