--luacheck: globals log
local log = log or print

local bgfx = require "bgfx"

local shader_mgr = {}
shader_mgr.__index = shader_mgr

local function uniform_info(uniforms, handles)
    for _, h in ipairs(handles) do
        local name, type, num = bgfx.get_uniform_info(h)
        if uniforms[name] == nil then
            uniforms[name] = { handle = h, name = name, type = type, num = num }
        end
    end
end

function shader_mgr.create_render_program(vs, fs)
    local prog = bgfx.create_program(assert(vs.handle), assert(fs.handle), true)

    if prog then
        local proguniforms = {}
        uniform_info(proguniforms, vs.unifroms)
        uniform_info(proguniforms, fs.uniforms)
    else
        error(string.format("create program failed, vs:%d, fs:%d", vs.handle, fs.handle))
    end
    return prog
end

function shader_mgr.create_compute_program(cs)
    return bgfx.create_program(cs.handle, true)
end

function shader_mgr.destroy_program(shader)
    bgfx.destroy(assert(shader.prog))
	shader.prog = nil
	shader.uniforms = nil
end

return shader_mgr