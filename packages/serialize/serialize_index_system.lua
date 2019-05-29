local ecs = ...
local world = ecs.world

local serialize_index_system = ecs.system 'serialize_index_system'

function serialize_index_system:update()
    for eid in world:each_new("serialize") do
        local serialize = world[eid].serialize
        world:set_serialize2eid(serialize, eid)
    end
    if world._removed then
        for k,v in ipairs(world._removed) do
            local serialize = v[2].serialize
            if serialize then
                world:set_serialize2eid(serialize, nil)
            end
        end
    end
end