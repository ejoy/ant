local ecs = ...
local world = ecs.world
local w = world.w

local m = ecs.system "prefab_system"

local evRemoveInstance1 = world:sub {"RemoveInstance1"}
local evRemoveInstance2 = world:sub {"RemoveInstance2"}

function m:data_changed()
    for _, instance in evRemoveInstance1:unpack() do
        world:pub {"RemoveInstance2", instance}
    end
end

function m:prefab_remove()
    for _, instance in evRemoveInstance2:unpack() do
        if instance.proxy then
            w:remove(instance.proxy)
        end
        for _, entity in ipairs(instance.tag["*"]) do
            w:remove(entity)
        end
    end
end
