local cr = require "thread.compile"
local serialize = import_package "ant.serialize"
local lfs = require "filesystem.local"
local fs  = require "filesystem"
local bgfx = require "bgfx"

local function readall(filename)
    local f <close> = assert(lfs.open(cr.compile(filename), "rb"))
    return f:read "a"
end

local function uniform_info(shader, uniforms, mark)
    local shader_uniforms = bgfx.get_shader_uniforms(shader)
    if shader_uniforms then
        for _, h in ipairs(shader_uniforms) do
            local name, type, num = bgfx.get_uniform_info(h)
            if not mark[name] then
                mark[name] = true
                uniforms[#uniforms + 1] = { handle = h, name = name, type = type, num = num }
            end
        end
    end
end

local function loadShader(filename, fxcfg, stage)
    if fxcfg[stage] then
        local n = filename .. "|" .. stage .. ".bin"
        local h = bgfx.create_shader(readall(n))
        bgfx.set_name(h, n)
        return h
    end
end

local function fetch_uniforms(h, ...)
    local uniforms, mark = {}, {}
    local function fetch_uniforms_(h, ...)
        if h then
            uniform_info(h, uniforms, mark)
            return fetch_uniforms_(...)
        end
    end
    fetch_uniforms_(h, ...)
    return uniforms
end

local function createRenderProgram(filename, fxcfg)
    local vh = loadShader(filename, fxcfg, "vs")
    local fh = loadShader(filename, fxcfg, "fs")
    local prog = bgfx.create_program(vh, fh, false)
    if prog then
        return {
            setting = fxcfg.setting or {},
            vs = vh,
            fs = fh,
            prog = prog,
            uniforms = fetch_uniforms(vh, fh),
        }
    else
        error(("create program failed, filename:%s"):format(filename))
    end
end

local function createComputeProgram(filename, fxcfg)
    local ch = loadShader(filename, fxcfg, "cs")
    local prog = bgfx.create_program(ch, false)
    if prog then
        return {
            setting = fxcfg.setting or {},
            cs = ch,
            prog = prog,
            uniforms = fetch_uniforms(ch),
        }
    else
        error(string.format("create program failed, cs:%d", ch))
    end
end

local S = {}

local function is_compute_material(fxcfg)
    return fxcfg.shader_type == "COMPUTE"
end

function S.shader_create(name)
    local material = serialize.parse(name, readall(name .. "|main.cfg"))
    local fxcfg = assert(material.fx, "Invalid material")
    material.fx = is_compute_material(fxcfg) and 
                    createComputeProgram(name, fxcfg) or
                    createRenderProgram(name, fxcfg)
    return material
end

return {
    S = S
}
