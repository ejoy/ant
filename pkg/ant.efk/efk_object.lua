local ecs   = ...
local world = ecs.world
local w     = world.w

local mathpkg   = import_package "ant.math"
local mu        = mathpkg.constant

local eo = ecs.component "efk_object"
local function init_eo()
    return {
        visible_masks = 0,
        handle = 0,
        worldmat = mu.NULL,
    }
end
function eo.init()
    return init_eo()
end

function eo.marshal()
    return ""
end

function eo.unmarshal()
    return init_eo()
end