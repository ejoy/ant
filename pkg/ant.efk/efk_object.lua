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

local eh = ecs.component "efk_hitch"
function eh.init()
    return {
        handle = 0,
        hitchmat = mu.NULL,
        worldmat = mu.NULL,
    }
end

local ehc = ecs.component "efk_hitch_counter"
function ehc.init()
    return {
        count = 0
    }
end