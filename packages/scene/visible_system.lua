local ecs = ...
local world = ecs.world

ecs.component_alias("hierarchy_visible", "boolean")

-- local visible_change_cache = ecs.singleton "visible_change_cache"
-- function visible_change_cache:init()
--     local cache
--     local function clear( )
--         cache.list = {}
--     end
--     cache = {
--         clear = clear,
--         list = {},
--     }
--     return cache
-- end


local visible_system = ecs.system "visible_system"
-- visible_system.singleton "visible_change_cache"

-- function visible_system:update()
--     local change_cache_list = self.visible_change_cache.list
--     for eid in world:each_new("hierarchy_visible") do
--         table.insert(change_cache_list,eid)
--     end
-- end

local function combine_and_return_visible(eid,updated_visible)
    local v = updated_visible[eid]
    if v ~= nil then
        return v
    end
    local entity = world[eid]
    if not entity then
        updated_visible[eid] = true
        return true
    end
    if entity.hierarchy_visible == false then
        updated_visible[eid] = false
        return false
    else--visible is true or nil
        local t = entity.transform or entity.hierarchy_transform
        local pid = t and t.parent
        if pid then
            local parent_visible = combine_and_return_visible(pid,updated_visible)
            updated_visible[eid] = parent_visible
            return parent_visible
        else
            updated_visible[eid] = true
            return true
        end
    end
end

function visible_system:after_update()
    -- local change_cache_list = self.visible_change_cache.list
    local updated_visible = {}
    for _,eid in world:each("can_render") do
        local entity = world[eid]
        local v = combine_and_return_visible(eid,updated_visible)
        entity.can_render = v
    end
    -- self.visible_change_cache.clear()

end