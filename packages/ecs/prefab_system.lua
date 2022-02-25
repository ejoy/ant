local ecs = ...
local world = ecs.world
local w = world.w

local m = ecs.system "prefab_system"

local evObjectMessage = world:sub {"object_message"}
local evObjectDetach  = world:sub {"object_detach"}
local evObjectRemove  = world:sub {"object_remove"}

local evPrefabDetach  = world:sub {"prefab_system", "detach"}
local evPrefabRemove  = world:sub {"prefab_system", "remove"}

local function isValidReference(reference)
    assert(reference[2] == 1, "Not a reference")
    return reference[1] ~= nil
end

function m:entity_init()
    for v in w:select "on_init:in" do
        v:on_init()
    end
    w:clear "on_init"
end

function m:entity_ready()
    for v in w:select "on_ready:in" do
        v:on_ready()
    end
    w:clear "on_ready"
    for _, prefab in evObjectDetach:unpack() do
        world:pub{"prefab_system", "detach", prefab}
    end
    for _, prefab in evObjectRemove:unpack() do
        world:pub{"prefab_system", "remove", prefab}
    end
end

function m:data_changed()
    for msg in evObjectMessage:each() do
        local f = msg[2]
        f(table.unpack(msg, 3))
    end
    for v in w:select "on_update:in" do
        v:on_update()
    end
end

function m:entity_remove()
    for _, _, id in evPrefabDetach:unpack() do
        local prefab = world:entity(id)
        if prefab then
            world:detach_instance(prefab.prefab)
            world:remove_entity(id)
        end
    end
    for _, _, id in evPrefabRemove:unpack() do
        local prefab = world:entity(id)
        if prefab then
            local instance = prefab.prefab
            w:remove(instance.root)
            for _, entity in ipairs(instance.tag["*"]) do
                world:remove_entity(entity)
            end
            world:remove_entity(id)
        end
    end
end
