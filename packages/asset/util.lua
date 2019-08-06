local util = {}; util.__index = util

local shader_mgr = require "shader_mgr"
local assetmgr = require "asset"

function util.load_shader_program(shader)
    if shader.cs == nil then
        local vs = assetmgr.load(shader.vs)
        local fs = assetmgr.load(shader.fs)
        
        shader.prog, shader.uniforms = shader_mgr.create_render_program(vs, fs)
    else
        local cs = assetmgr.load(shader.cs)
        shader.prog, shader.uniforms = shader_mgr.create_compute_program(cs)
    end
    return shader
end

util.unload_shader_program = shader_mgr.destroy_program

return util