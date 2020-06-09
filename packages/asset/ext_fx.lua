local bgfx      = require "bgfx"
local cr        = import_package "ant.compile_resource"
local lfs       = require "filesystem.local"
local datalist  = require "datalist"

local function set_uniform_texture(u, property)
    --TODO: 'stage' info has been written in shader compiled file by bgfx, but it does not keep in memory after reload shader binary file
    -- see: bgfx_p.h:createShader function
    bgfx.set_texture(property.stage, u.handle, property.texture.handle)
end

local function set_uniform(u, property)
    bgfx.set_uniform(u.handle, property)
end

local function set_uniform_array(u, property)
    bgfx.set_uniform(u.handle, table.unpack(property))
end

local function create_uniform(h, mark)
    local name, type, num = bgfx.get_uniform_info(h)
    if mark[name] then
        return
    end
    mark[name] = true
    local uniform = { handle = h, name = name, type = type, num = num }
    if type == "s" then
        assert(num == 1)
        uniform.set = set_uniform_texture
    else
        assert(type == "v4" or type == "m4")
        if num == 1 then
            uniform.set = set_uniform
        else
            uniform.set = set_uniform_array
        end
    end
    return uniform
end

local function uniform_info(shader, uniforms, mark)
    for _, h in ipairs(bgfx.get_shader_uniforms(shader)) do
        uniforms[#uniforms+1] = create_uniform(h, mark)
    end
end

local function create_render_program(vs, fs)
    local prog = bgfx.create_program(vs, fs, false)
    if prog then
        local uniforms = {}
        local mark = {}
        uniform_info(vs, uniforms, mark)
        uniform_info(fs, uniforms, mark)
        return prog, uniforms
    else
        error(string.format("create program failed, vs:%d, fs:%d", vs, fs))
    end
end

local function create_compute_program(cs)
    local prog = bgfx.create_program(cs, false)
    if prog then
        local uniforms = {}
        local mark = {}
        uniform_info(cs, uniforms, mark)
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

local compile_setting = {}
local compile_config = {
    setting = {
        graphic = {
            compile = compile_setting
        }
    }
}

local function compile(filename, setting)
    if setting == nil then
        return cr.compile_fx(filename)
    end

    local macros = {}
    if setting.gpu_skinning then
        macros[#macros+1] = "GPU_SKINNING"
    end
    compile_setting.macros = macros

    return cr.compile_fx(filename, compile_config)
end

local function loader(filename, setting)
    local outpath = compile(filename, setting)
    local res = datalist.parse(readfile(outpath / "main.fx"))
    local shader = res.shader
    if shader.cs == nil then
        local vs = load_shader(outpath / "vs", shader.vs)
        local fs = load_shader(outpath / "fs", shader.fs)
        res.prog, res.uniforms = create_render_program(vs, fs)
    else
        local cs = load_shader(outpath / "cs", shader.cs)
        res.prog, res.uniforms = create_compute_program(cs)
    end
    return res
end

local function unloader(res)
    bgfx.destroy(assert(res.shader.prog))
end

return {
    loader = loader,
    unloader = unloader,
}
