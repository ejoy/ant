local util = {}; util.__index = util

local shader_mgr = require "shader_mgr"

function util.shader_loader(shader)
    local uniforms = {}
    shader.prog = shader_mgr.programLoad(assert(shader.vs), assert(shader.fs), uniforms)
    assert(shader.prog ~= nil)
    shader.uniforms = uniforms
    return shader
end

return util