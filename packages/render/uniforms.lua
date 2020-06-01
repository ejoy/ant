local ecs = ...

local m = ecs.interface "uniforms"

local system_uniforms = {
    s_mainview          = {stage=6},
    s_postprocess_input = {stage=7},
    s_shadowmap         = {stage=7},
}

function m.system_uniform(name)
    return system_uniforms[name]
end
