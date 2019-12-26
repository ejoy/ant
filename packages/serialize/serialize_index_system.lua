local ecs = ...
local world = ecs.world

local m = ecs.singleton "serialize2eid"
function m.init()
    local o = {_serialize_to_eid={}}
    function o:set(serialize_id,eid)
        assert(serialize_id,
            "function world:set_serialize2eid\nserialize_id can't be nil")
        self._serialize_to_eid[serialize_id] = eid
    end
    function o:find(serialize_id)
        assert(serialize_id,
            "function world:set_serialize2eid\nserialize_id can't be nil")
        return self._serialize_to_eid[serialize_id]
    end
    return o
end

local serialize_index_system = ecs.system 'serialize_index_system'
local serialize_mb = world:sub {"component_register","serialize"}
local serialize_delete_mb = world:sub {"component_removed", "serialize"}

serialize_index_system.singleton "serialize2eid"


function serialize_index_system:update()
    for msg in serialize_mb:each() do
        local eid = msg[3]
        local serialize = world[eid].serialize
        self.serialize2eid:set(serialize, eid)
    end
    for msg in serialize_delete_mb:each() do
        local cname = msg[2]
        local e = msg[4]
        local serialize = e[cname]
        if serialize then
            self.serialize2eid:set(serialize, nil)
        end
    end
end
