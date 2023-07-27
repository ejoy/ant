local cr = require "thread.compile"
local serialize = import_package "ant.serialize"
local lfs = require "filesystem.local"
local bgfx = require "bgfx"

local PM = require "programan.server"
PM.program_init{
    max = bgfx.get_caps().limits.maxPrograms - bgfx.get_stats "n".numPrograms
}

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
        local n = ("%s|%s.bin"):format(filename, stage)
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

local function from_handle(handle)
    local pid = PM.program_new()
    PM.program_set(pid, handle)
    return pid
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
            prog = from_handle(prog),
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
            prog = from_handle(prog),
            uniforms = fetch_uniforms(ch),
        }
    else
        error(string.format("create program failed, cs:%d", ch))
    end
end

local S = require "thread.main"

local function is_compute_material(fxcfg)
    return fxcfg.shader_type == "COMPUTE"
end

local function absolute_path(path, base)
    if path:sub(1,1) == "/" then
        return path
    end
    return base:match "^(.-)[^/|]*$" .. (path:match "^%./(.+)$" or path)
end

function S.material_create(name)
    local material = serialize.parse(name, readall(name .. "|main.cfg"))
    local fxcfg = assert(material.fx, "Invalid material")
    material.fx = is_compute_material(fxcfg) and 
                    createComputeProgram(name, fxcfg) or
                    createRenderProgram(name, fxcfg)
    if material.properties then
        for _, v in pairs(material.properties) do
            if v.texture then
                v.type = 't'
                local texturename = absolute_path(v.texture, name)
                v.value = S.texture_create_fast(texturename)
            elseif v.image then
                v.type = 'i'
                local texturename = absolute_path(v.image, name)
                v.value = S.texture_create_fast(texturename)
            elseif v.buffer then
                v.type = 'b'
            end
        end
    end
    return material
end

function S.material_destroy(material)
    local fx = material.fx
    local h = PM.program_get(fx.prog)
    assert(h ~= 0xffff)
    bgfx.destroy(h)
    if is_compute_material(fx) then
        bgfx.destroy(fx.cs)
    else
        bgfx.destroy(fx.vs)
        bgfx.destroy(fx.fs)
    end
end
