local lm = require "luamake"
local fs = require "bee.filesystem"
local SHADERC = require "examples.util".tools_path ("shaderc")

require "tools.shaderc"

local platforms <const> = {
    windows = "windows",
    ios = "ios",
    macos = "osx",
    linux = "linux",
    android = "android",
}

local renderers <const> = {
    windows = "direct3d11",
    ios = "metal",
    osx = "metal",
    linux = "vulkan",
    android = "vulkan",
}

local stage_types <const> = {
    fs = "fragment",
    vs = "vertex",
    cs = "compute",
}

local shader_options <const> = {
    direct3d9 = {
        vs = "s_3_0",
        fs = "s_3_0",
        outname = "dx9",
    },
    direct3d11 = {
        vs = "s_5_0",
        fs = "s_5_0",
        cs = "s_5_0",
        outname = "dx11",
    },
    direct3d12 = {
        vs = "s_5_0",
        fs = "s_5_0",
        cs = "s_5_0",
        outname = "dx11",
    },
    opengl = {
        vs = "120",
        fs = "120",
        cs = "430",
        outname = "glsl",
    },
    metal = {
        vs = "metal",
        fs = "metal",
        cs = "metal",
        outname = "metal",
    },
    vulkan = {
        vs = "spirv",
        fs = "spirv",
        cs = "spirv",
        outname = "spirv",
    },
}

local function commandline(cfg)
    local platform = cfg.platform or platforms[lm.os]
    local renderer = cfg.renderer or renderers[platform]
    local stagename = cfg.stage
    local commands = {
        "-f", "$in", "-o", "$out",
        "--platform", platform,
        "--type", stage_types[stagename],
        "-p", shader_options[renderer][stagename],
        "--depends"
    }
    if cfg.varying_path then
        commands[#commands + 1] = "--varyingdef"
        commands[#commands + 1] = cfg.varying_path
    end
    if cfg.includes then
        for _, p in ipairs(cfg.includes) do
            commands[#commands + 1] = "-i"
            commands[#commands + 1] = p
        end
    end
    if cfg.defines then
        local t = {}
        for _, m in ipairs(cfg.defines) do
            t[#t + 1] = m
        end
        if #t > 0 then
            local defines = table.concat(t, ';')
            commands[#commands + 1] = "--define"
            commands[#commands + 1] = defines
        end
    end
    local level = cfg.optimizelevel
    if not level then
        if renderer:match("direct3d") then
            level = cfg.stage == "cs" and 1 or 3
        end
    end
    if cfg.debug then
        commands[#commands + 1] = "--debug"
    else
        if level then
            commands[#commands + 1] = "-O"
            commands[#commands + 1] = tostring(level)
        end
    end
    return commands
end

local m = {}
local rule = {}

local function set_rule(stage, renderer)
    local key = stage .. "_" .. renderer
    if rule[key] then
        return
    end
    rule[key] = true
    lm:rule("compile_shader_" .. key) {
        SHADERC,
        commandline {
            stage = stage,
            renderer = renderer,
            includes = {
                lm.BgfxDir / "src"
            }
        },
        description = "Compile shader $in",
        deps = "gcc",
        depfile = "$out.d",
    }
end

local function get_renderer()
    if lm.gl then
        return "opengl"
    end
    if lm.vk then
        return "vulkan"
    end
    if lm.noop then
        return "noop"
    end
    if lm.d3d9 then
        return "direct3d9"
    end
    if lm.d3d11 then
        return "direct3d11"
    end
    if lm.d3d12 then
        return "direct3d12"
    end
    if lm.mtl then
        return "metal"
    end
    return renderers[platforms[lm.os]]
end

local function compile(fullpath)
    local _, stage, name = fullpath:match "^(.*)/([cfv]s)_([^/]+)%.sc$"
    local renderer = get_renderer()
    local key = stage .. "_" .. renderer
    local target_name = ("shader-%s_%s"):format(key, name)
    if m[target_name] then
        return target_name
    end
    m[target_name] = true

    set_rule(stage, renderer)

    lm:build(target_name) {
        rule = "compile_shader_" .. key,
        input = lm.BgfxDir / fullpath,
        output = ("$bin/shaders/%s/%s_%s.bin"):format(shader_options[renderer].outname, stage, name),
        deps = "shaderc",
    }
    return target_name
end

local function compileall(dir)
    local r = {}
    local path = tostring(lm.BgfxDir .. "/" .. dir)
    for file in fs.pairs(path) do
        local filename = file:filename():string()
        if filename:match "^[cfv]s_[^/]+%.sc$" then
            r[#r + 1] = compile(dir .. "/" .. filename)
        end
    end
    return r
end

return {
    compile = compile,
    compileall = compileall,
}
