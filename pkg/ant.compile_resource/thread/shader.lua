local cr = import_package "ant.compile_resource"
local serialize = import_package "ant.serialize"
local lfs = require "filesystem.local"
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

local function loadShader(filename, data, stage)
    if data[stage] then
        local h = bgfx.create_shader(readall(filename .. "|" .. stage .. ".bin"))
        bgfx.set_name(h, data[stage])
        return h
    end
end

local function createRenderProgram(fx, filename, data)
    local vs = loadShader(filename, data, "vs")
    local fs = loadShader(filename, data, "fs")
    local prog = bgfx.create_program(vs, fs, false)
    if prog then
        local uniforms = {}
        local mark = {}
        uniform_info(vs, uniforms, mark)
        if fs then
            uniform_info(fs, uniforms, mark)
        end
        fx.vs = vs
        fx.fs = fs
        fx.prog = prog
        fx.uniforms = uniforms
    else
        error(string.format("create program failed, vs:%d, fs:%d", vs, fs))
    end
end

local function createComputeProgram(fx, filename, data)
    local cs = loadShader(filename, data, "cs")
    local prog = bgfx.create_program(cs, false)
    if prog then
        local uniforms = {}
        local mark = {}
        uniform_info(cs, uniforms, mark)
        fx.cs = cs
        fx.prog = prog
        fx.uniforms = uniforms
    else
        error(string.format("create program failed, cs:%d", cs))
    end
end

local S = {}

function S.shader_create(name)
    local material = serialize.parse(name, readall(name .. "|main.cfg"))
    local data = material.fx
    local fx = {
        setting = data.setting or {}
    }
    if data.vs then
        createRenderProgram(fx, name, data)
    elseif data.cs then
        createComputeProgram(fx, name, data)
    else
        error("material needs to contain at least cs or vs")
    end
    material.fx = fx
    return material
end

return {
    S = S
}
