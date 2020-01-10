local ecs = ...
local world = ecs.world

ecs.component "serialize2eid" {}
ecs.singleton "serialize2eid" {}

local serialize_index_system = ecs.system 'serialize_index_system'
local serialize_mb = world:sub {"component_register","serialize"}
local serialize_delete_mb = world:sub {"component_removed", "serialize"}

serialize_index_system.require_singleton "serialize2eid"

function serialize_index_system:update()
    local serialize2eid = world:singleton "serialize2eid"
    for _,_,eid in serialize_mb:unpack() do
        local serialize = world[eid].serialize
        serialize2eid[serialize] = eid
    end
    for _,_,_,e in serialize_delete_mb:each() do
        local serialize = e.serialize
        if serialize then
            serialize2eid[serialize] = nil
        end
    end
end
