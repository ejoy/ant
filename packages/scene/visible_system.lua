local ecs = ...
local world = ecs.world

ecs.component_alias ("hierarchy_visible","boolean",true)


local visible_system = ecs.system "visible_system"


local NotUpdated = nil
local DontHave = 0
local HaveTrue = true
local HaveFalse = false
--updated_visible:
    -- nil -> not updated
    -- 0 -> dont have hierarchy_visible
    -- 1 -> have hierarchy_visible and AND(all) true
    -- -1 -> have hierarchy_visible and AND(all) is false
local function combine_and_return_visible(eid,updated_visible)
    local v = updated_visible[eid]
    if v ~= NotUpdated then
        return v
    end
    local entity = world[eid]
    if not entity then
        updated_visible[eid] = DontHave
        return DontHave
    end
    if entity.hierarchy_visible ~= nil then
        if entity.hierarchy_visible == false then
            updated_visible[eid] = HaveFalse
        else -- entity.hierarchy_visible == true
            local t = entity.transform
            local pid = t and t.parent
            if pid then
                local parent_visible = combine_and_return_visible(pid,updated_visible)
                updated_visible[eid] = parent_visible and true
            else
                updated_visible[eid] = true
            end
        end
    else
        updated_visible[eid] = DontHave
    end
    return updated_visible[eid]
end

function visible_system:after_update()
    -- local change_cache_list = self.visible_change_cache.list
    local updated_visible = {}
    for _,eid in world:each("can_render") do
        local entity = world[eid]
        local v = combine_and_return_visible(eid,updated_visible)
        assert( v ~= nil )
        if v ~= DontHave then
            entity.can_render = v
        end
    end
    -- self.visible_change_cache.clear()

end