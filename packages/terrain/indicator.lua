local ecs   = ...
local world = ecs.world
local w     = world.w

local is        = ecs.system "indicator_system"
function is:data_changed()
end