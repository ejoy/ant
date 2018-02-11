local require = import and import(...) or require
local rawtable = require "rawtable"
local bgfx = require "bgfx"

return function (filename)
    local uniforms = rawtable(filename)
    for u_name, u_value in pairs(uniforms) do
        local uniform = uniforms[u_name]        
        assert(u_name == uniform.name)
        uniform.id = bgfx.create_uniform(u_name, u_value.type)
        assert(uniform.id, "uniform_name : " .. u_name)
    end

    return uniforms
end

