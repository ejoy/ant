local uniforms = {}; uniforms.__index = uniforms

local system_uniforms = {
    s_mainview          = {type="texture", stage=6},
    s_postprocess_input = {type="texture", stage=7},
    s_shadowmap         = {type="texture", stage=7},
}

function uniforms.system_uniform(name)
    return system_uniforms[name]
end

return uniforms