local ecs = ...

local bgfx      = require "bgfx"
local cr        = import_package "ant.compile_resource"
local lfs       = require "filesystem.local"
local datalist  = require "datalist"

local function uniform_info(uniforms, shader)
    for _, h in ipairs(bgfx.get_shader_uniforms(shader)) do
        local name, type, num = bgfx.get_uniform_info(h)
        if uniforms[name] == nil then
            uniforms[name] = { handle = h, name = name, type = type, num = num }
        end
    end
end

local function create_render_program(vs, fs)
    local prog = bgfx.create_program(vs, fs, false)
    if prog then
        local uniforms = {}
        uniform_info(uniforms, vs)
        uniform_info(uniforms, fs)
        return prog, uniforms
    else
        error(string.format("create program failed, vs:%d, fs:%d", vs, fs))
    end
end

local function create_compute_program(cs)
    local prog = bgfx.create_program(cs, false)
    if prog then
        local uniforms = {}
        uniform_info(uniforms, cs)
        return prog, uniforms
    else
        error(string.format("create program failed, cs:%d", cs))
    end
end

local function readfile(filename)
	local f = assert(lfs.open(filename, "rb"))
	local data = f:read "a"
	f:close()
	return data
end

local function load_shader(path, name)
    local h = bgfx.create_shader(readfile(path))
    bgfx.set_name(h, name)
    return h
end

local m = ecs.component "fx"

function m:init()
    local filename = self
    local outpath = cr.compile(filename)
    local config = datalist.parse(readfile(outpath / "main.fx"))
    local shader = config.shader
    if shader.cs == nil then
        local vs = load_shader(outpath / "vs", shader.vs)
        local fs = load_shader(outpath / "fs", shader.fs)
        shader.prog, shader.uniforms = create_render_program(vs, fs)
    else
        local cs = load_shader(outpath / "cs", shader.cs)
        shader.prog, shader.uniforms = create_compute_program(cs)
    end
    return config
end

function m:delete()
    bgfx.destroy(assert(self.shader.prog))
end
