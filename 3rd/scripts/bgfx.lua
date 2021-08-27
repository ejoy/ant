local lm = require "luamake"

local EnableEditor = lm.os ~= "ios"

require "bgfx.bx"
require "bgfx.bimg"
require "bgfx.bgfx-lib"

if not EnableEditor then
    lm:phony "bgfx_make" {
        "bgfx-lib"
    }
else
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

    if lm.compiler == "msvc" then
        lm:build "mt_bgfx_texturec" {
            "mt", "-nologo", "-manifest", "@utf8.manifest", "-outputresource:$in;#1",
            input = "$bin/texturec.exe",
            deps = "texturec",
        }
        lm:build "mt_bgfx_shaderc" {
            "mt", "-nologo", "-manifest", "@utf8.manifest", "-outputresource:$in;#1",
            input = "$bin/shaderc.exe",
            deps = "shaderc",
        }
    end

    lm:phony "bgfx_make" {
        deps = {
            "copy_bgfx_shader",
            "bgfx-core",
            "shaderc",
            "texturec",
        },
        msvc = {
            deps = {
                "mt_bgfx_texturec",
                "mt_bgfx_shaderc",
            }
        }
    }
end
