    
local function gen_editor_world(base_world)
    local datalist = require "datalist"
    local serialize = import_package 'ant.serialize'

    local editor_world = {}
    function editor_world:register_entity(policies, dataset)
        local eid = base_world.register_entity(self, policies, dataset)
        if self[eid] then
            self.entity_policies = self.entity_policies or {}
            self.entity_policies[eid] = policies
        end
        return eid
    end

    -- create new serialize_id,otherwise,serialize_id may conflict with origin entity
    function editor_world:instantiate_entity(t)
        if type(t) == 'string' then
            local d = datalist.parse(t)
            return self:instantiate_entity({policy=d[1],data=d[2]})
        elseif type(t) == 'table' then -- {policy={},data={}}
            local component = t.data
            if component and component.serialize then
                component.serialize = serialize.create()
            end
            return self:create_entity(t)
        else
            log.error("Instantiate_entity support str/tbl only")
        end
    end

    function editor_world:add_policy(eid,t)
        base_world.add_policy(self,eid,t)
        for _,p in ipairs(t.policy) do
            table.insert( self.entity_policies[eid],p)
        end
    end

    function editor_world:get_entity_policies(eid)
        return self.entity_policies[eid]
    end
    -- editor_world.name = "EDITOR_WORLD>>>>>>>>>>>>>>>>>>>>>>>"
    setmetatable(editor_world,{__index = base_world})
    editor_world.__index = editor_world
    return editor_world
end

return function()
    local ecs = import_package "ant.ecs"
    local base_world = ecs.world_base
    return gen_editor_world(base_world)
end
