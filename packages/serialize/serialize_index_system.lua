local ecs = ...
local world = ecs.world

local serialize_index_system = ecs.system 'serialize_index_system'
local serialize_mb = world:sub {"component_register","serialize"}
local serialize_delete_mb = world:sub {"component_removed", "serialize"}

function serialize_index_system:update()
    for msg in serialize_mb:each() do
        local eid = msg[3]
        local serialize = world[eid].serialize
        world:set_serialize2eid(serialize, eid)
    end
    
        for msg in serialize_delete_mb:each() do
            local cname = msg[2]
            local e = msg[4]
            local serialize = e[cname]
            if serialize then
                world:set_serialize2eid(serialize, nil)
            end
        end
    
end