local ecs   = ...
local world = ecs.world
local w     = world.w

local mathpkg   = import_package "ant.math"
local mu        = mathpkg.constant

local eo = ecs.component "efk_object"

function eo.init()
    return {
        visible_masks = 0,
        handle = 0,
        worldmat = mu.NULL,
    }
end

local eh = ecs.component "efk_hitch"
function eh.init()
    return {
        handle = 0,
        hitchmat = mu.NULL,
    }
end
