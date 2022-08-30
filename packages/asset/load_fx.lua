local cr = import_package "ant.compile_resource"
local serialize = import_package "ant.serialize"
local lfs = require "filesystem.local"
local bgfx = require "bgfx"

local function readall(filename)
    local f <close> = assert(lfs.open(cr.compile(filename), "rb"))
    return f:read "a"
end

local function create_uniform(h, mark)
    local name, type, num = bgfx.get_uniform_info(h)
    if mark[name] then
        return
    end
    mark[name] = true
    return { handle = h, name = name, type = type, num = num }
end

local function uniform_info(shader, uniforms, mark)
    local shader_uniforms = bgfx.get_shader_uniforms(shader)
    if shader_uniforms then
        for _, h in ipairs(shader_uniforms) do
            uniforms[#uniforms+1] = create_uniform(h, mark)
        end
    end
end

local function createRenderProgram(vs, fs)
    local prog = bgfx.create_program(vs, fs, false)
    if prog then
        local uniforms = {}
        local mark = {}
        uniform_info(vs, uniforms, mark)
        if fs then
            uniform_info(fs, uniforms, mark)
        end
        return prog, uniforms
    else
        error(string.format("create program failed, vs:%d, fs:%d", vs, fs))
    end
end

local function createComputeProgram(cs)
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

local function createProgram(filename, fx)
    local function loadFxShader(stage)
        if fx[stage] then
            local h = bgfx.create_shader(readall(filename.."|"..stage..".bin"))
            bgfx.set_name(h, fx[stage])
            return h
        end
    end

    local result = {}
    if fx.cs then
        result.cs = loadFxShader "cs"
        result.prog, result.uniforms = createComputeProgram(result.cs)
    else
        result.vs, result.fs = loadFxShader "vs", loadFxShader "fs"
        result.prog, result.uniforms = createRenderProgram(result.vs, result.fs)
    end
    result.setting = fx.setting or {}
    return result
end

return function (filename)
    local material = serialize.parse(filename, readall(filename.."|main.cfg"))
    material.fx = createProgram(filename, material.fx)
    return material
end
