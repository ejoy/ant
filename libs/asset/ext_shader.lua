-- luacheck: globals import
local require = import and import(...) or require

local rawtable = require "rawtable"

return function (filename)    
    local shader_mgr = require "render.resources.shader_mgr"
    
    local shader = rawtable(filename)
    
    local uniforms = {}
    shader.prog = shader_mgr.programLoad(assert(shader.vs), assert(shader.fs), uniforms)
    assert(shader.prog ~= nil)
    shader.uniforms = uniforms
    return shader
end

