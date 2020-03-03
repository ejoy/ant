
local function gen_editor_world(base_world)
    local editor_world = {}
    function editor_world:set_entity(eid, policies, dataset)
        base_world.set_entity(self,eid, policies, dataset)
        if self[eid] then
            self.entity_policies = self.entity_policies or {}
            self.entity_policies[eid] = policies
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