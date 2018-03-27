local require = import and import(...) or require

local rawtable = require "rawtable"


return function (filename)    
    local shader_mgr = require "render.resources.shader_mgr"
    local shader = rawtable(filename)
    
    shader.prog = shader_mgr.programLoad(assert(shader.vs), assert(shader.fs))
    assert(shader.prog ~= nil)
    return shader
end

