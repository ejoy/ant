local lm = require "luamake"

local EnableEditor = lm.os ~= "ios"

require "bgfx.bx"
require "bgfx.bimg"
require "bgfx.bgfx-lib"

if not EnableEditor then
    return
end

require "bgfx.bgfx-dll"
require "bgfx.shaderc"
require "bgfx.texturec"

lm:copy "copy_bgfx_shader" {
    input = {
        "../bgfx/src/bgfx_shader.sh",
        "../bgfx/src/bgfx_compute.sh",
        "../bgfx/examples/common/common.sh",
        "../bgfx/examples/common/shaderlib.sh",
    },
    output = {
        "../../packages/resources/shaders/bgfx_shader.sh",
        "../../packages/resources/shaders/bgfx_compute.sh",
        "../../packages/resources/shaders/common.sh",
        "../../packages/resources/shaders/shaderlib.sh",
    }
}
