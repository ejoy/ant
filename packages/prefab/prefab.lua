local ecs = ...
local world = ecs.world

local iprefab = ecs.interface "iprefab"

function iprefab.get_entity(prefab, name)
    if not prefab.__class then
        return
    end
    local index
    for i, c in ipairs(prefab.__class) do
        if c.data.name == name then
            index = i
            break
        end
    end
    if index then
        return prefab[index]
    end
end

function iprefab.get_property(eid, name)
    if not eid or not world[eid] then
        return
    end
end