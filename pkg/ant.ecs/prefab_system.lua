local ecs = ...
local world = ecs.world
local w = world.w

local m = ecs.system "prefab_system"

local evObjectMessage = world:sub {"object_message"}
local evObjectRemove  = world:sub {"object_remove"}

local evPrefabRemove  = world:sub {"prefab_system", "remove"}

function m:data_changed()
    for _, prefab in evObjectRemove:unpack() do
        world:pub{"prefab_system", "remove", prefab}
    end
    for msg in evObjectMessage:each() do
        local f = msg[2]
        f(table.unpack(msg, 3))
    end
end

function m:prefab_remove()
    for _, _, id in evPrefabRemove:unpack() do
        local prefab <close> = world:entity(id, "prefab?in")
        if prefab and prefab.prefab then
            local instance = prefab.prefab
            for _, entity in ipairs(instance.tag["*"]) do
                w:remove(entity)
            end
            w:remove(id)
        end
    end
end
