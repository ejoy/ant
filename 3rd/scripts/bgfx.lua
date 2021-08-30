local lm = require "luamake"

local EnableEditor = lm.os ~= "ios"

lm.warnings = {
    "error",
    "on"
}

lm.cxx = "c++17"

lm.msvc = {
    defines = "_CRT_SECURE_NO_WARNINGS",
    includes = "../bx/include/compat/msvc",
}

lm.mingw = {
    includes = "../bx/include/compat/mingw",
}

lm.macos = {
    includes = "../bx/include/compat/osx",
}

lm.ios = {
    includes = "../bx/include/compat/ios",
    flags = {
        "-fembed-bitcode",
        "-fobjc-arc"
    }
}

require "bgfx.bx"
require "bgfx.bimg"
require "bgfx.bgfx-lib"

if not EnableEditor then
    return
end

require "bgfx.bgfx-dll"
require "bgfx.shaderc"
require "bgfx.texturec"
require "bgfx.texturev"

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
