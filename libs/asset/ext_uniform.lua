local require = import and import(...) or require
local rawtable = require "rawtable"


return function (filename)
    local bgfx = require "bgfx"
    local uniforms = rawtable(filename)
    local references = uniforms.references
    local defines = uniforms.defines
    
    for u_name, u_value in pairs(defines) do
        local uniform = defines[u_name]
        assert(u_name == uniform.name)
        uniform.id = bgfx.create_uniform(u_name, u_value.type)
        assert(uniform.id, "uniform_name : " .. u_name)
    end

    return {references=references, defines=defines}
end

