local util = {}; util.__index = util

function util.shader_loader(shader)
	local shader_mgr = import_package "render" .shader_mgr
    
    local uniforms = {}
    shader.prog = shader_mgr.programLoad(assert(shader.vs), assert(shader.fs), uniforms)
    assert(shader.prog ~= nil)
    shader.uniforms = uniforms
    return shader
end

return util