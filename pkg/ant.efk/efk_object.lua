local ecs   = ...
local world = ecs.world
local w     = world.w

local mathpkg   = import_package "ant.math"
local mu        = mathpkg.constant

local eo = ecs.component "efk_object"
function eo.init(v)
    return {
        visible_masks = 0,
        handle = 0,
        worldmat = mu.NULL,
    }
end