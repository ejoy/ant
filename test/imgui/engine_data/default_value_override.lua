local default_component_value = require "engine_data.default_value_component"
assert(default_component_value)
local policies = {
    -- ["ant.render|light.directional"] = {
    --     directional_light = {
    --         50,{},true,
    --     }        
    -- }
}
local components = setmetatable({},{__index = default_component_value})
return {
    policies = policies,
    components = components,
}