local ecs = ...
local world = ecs.world

local t = ecs.transform "luaecs_filter_transform"

function t.process_entity(e)
    world:pub {"create_filter", e}
end
