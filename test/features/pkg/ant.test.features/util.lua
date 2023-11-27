local ecs   = ...
local world = ecs.world
local w     = world.w

local util = {}

function util.create_instance(p, on_ready)
    return world:create_instance {
        prefab = p,
        on_ready = on_ready,
    }
end

return util