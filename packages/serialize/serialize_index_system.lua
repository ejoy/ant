local ecs = ...
local world = ecs.world

local serialize_index_system = ecs.system 'serialize_index_system'
local serialize_mb = world:sub {"serialize"}
function serialize_index_system:update()
    for msg in serialize_mb:each() do
        local eid = msg[2]
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