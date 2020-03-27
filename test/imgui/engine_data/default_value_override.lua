local default_component_value = require "engine_data.default_value_component"
assert(default_component_value)
local policies = {
    -- ["ant.render|light.directional"] = {
    --     directional_light = {
    --         50,{},true,
    --     }        
    -- }
}
local components = setmetatable({
    serialize = function()
        local seriazlizeutil= import_package "ant.serialize"
        return seriazlizeutil.create()
    end,
},{__index = default_component_value})
return {
    policies = policies,
    components = components,
}