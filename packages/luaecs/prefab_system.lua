local ecs = ...
local world = ecs.world
local w = world.w

local m = ecs.system "prefab_system"

local evObjectMessage = world:sub {"object_message"}
local evObjectDetach  = world:sub {"object_detach"}

local function isValidReference(reference)
    return reference[1] ~= nil
end

function m:entity_init()
    for v in w:select "prefab_init:in" do
        v.prefab_init()
    end
    w:clear "prefab_init"
end

function m:entity_ready()
    for v in w:select "prefab_ready:in" do
        v.prefab_ready()
    end
    w:clear "prefab_ready"
end

function m:data_changed()
    for msg in evObjectMessage:each() do
        local f = msg[2]
        f(table.unpack(msg, 3))
    end
    for v in w:select "prefab_update:in" do
        v.prefab_update()
    end
end

function m:entity_remove()
    for _, prefab in evObjectDetach:unpack() do
        if isValidReference(prefab) then
            w:sync("prefab:in", prefab)
            world:detach_instance(prefab.prefab)
            w:remove(prefab)
        end
    end
end
