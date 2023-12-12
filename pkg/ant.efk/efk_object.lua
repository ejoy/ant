local ecs   = ...
local world = ecs.world
local w     = world.w

local mathpkg   = import_package "ant.math"
local mu        = mathpkg.constant

local eo = ecs.component "efk_object"

function eo.init()
    return {
        visible_idx = 0xffffffff,
        handle      = 0,
        worldmat    = mu.NULL,
    }
end

local function DEFINE_efk_hitch(name)
    local eh = ecs.component(name)
    function eh.init()
        return {
            handle = 0,
            hitchmat = mu.NULL,
        }
    end
end

DEFINE_efk_hitch "efk_hitch"
DEFINE_efk_hitch "efk_hitch_backbuffer"
