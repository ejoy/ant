local lm = require "luamake"
local SHADERC = require "examples.util".tools_path ("shaderc")

require "tools.shaderc"

local shader_target <const> = {
    { type = "glsl", args = { "--platform", "linux", "-p", "120" } },
    { type = "essl", args = { "--platform", "android" } },
    { type = "spv",  args = { "--platform", "linux", "-p", "spirv" } },
    { type = "dx9",  args = { "--platform", "windows", "-p", "s_3_0", "-O", "3" } },
    { type = "dx11", args = { "--platform", "windows", "-p", "s_4_0", "-O", "3" } },
    { type = "mtl",  args = { "--platform", "ios", "-p", "metal", "-O", "3" } },
}

for _, v in ipairs(shader_target) do
    lm:rule("compile_shader_fs_"..v.type) {
        SHADERC, "--type", "f", "-f", "$in", "-o", "$out",
        v.args,
        description = "Compile "..v.type.." shader $in",
        deps = "gcc",
        depfile = "$out.d",
    }
    lm:rule("compile_shader_vs_"..v.type) {
        SHADERC, "--type", "v", "-f", "$in", "-o", "$out",
        v.args,
        description = "Compile "..v.type.." shader $in",
        deps = "gcc",
        depfile = "$out.d",
    }
end

local shader_file <const> = {
    "vs_debugfont",
    "fs_debugfont",
    "vs_clear",
    "fs_clear0",
    "fs_clear1",
    "fs_clear2",
    "fs_clear3",
    "fs_clear4",
    "fs_clear5",
    "fs_clear6",
    "fs_clear7",
}

local inputs = {}
for _, name in ipairs(shader_file) do
    local shader_type = name:sub(1, 2)
    local binfiles = {}
    for _, v in ipairs(shader_target) do
        local binfile = ("$bin/embedded_shader/%s/%s.bin"):format(name, v.type)
        binfiles[#binfiles+1] = binfile
        lm:build {
            rule = "compile_shader_"..shader_type.."_"..v.type,
            input = lm.BgfxDir / "src" / (name..".sc"),
            output = binfile,
            deps = "shaderc",
        }
    end

    local output = lm.BgfxDir / "src" / (name..".bin.h")
    lm:runlua {
        script = "core/embedded_shader/embed.lua",
        args = { "$out", "$in" },
        input = binfiles,
        output = output,
    }
    inputs[#inputs+1] = output
end

lm:phony "embedded_shader" {
    input = inputs,
    output = lm.BgfxDir / "src"/ "bgfx.cpp",
}
