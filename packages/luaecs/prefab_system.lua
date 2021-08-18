local ecs = ...
local world = ecs.world
local w = world.w

local m = ecs.system "prefab_system"

local evObjectMessage = world:sub {"object_message"}
local evObjectDetach  = world:sub {"object_detach"}
local evEntityCommand = world:sub {"entity_command"}

local function isValidReference(reference)
    return reference[1] ~= nil
end

local function run_command(e, name, ...)
    --TODO
    print(e, name, ...)
end

function m:entity_init()
    for v in w:select "prefab_init:in" do
        v.prefab_init()
    end
    w:clear "prefab_init"
end

function m:data_changed()
    for msg in evObjectMessage:each() do
        local f = msg[2]
        f(table.unpack(msg, 3))
    end
    for msg in evEntityCommand:each() do
        run_command(table.unpack(msg, 2))
    end
    for v in w:select "prefab_update:in" do
        v.prefab_update()
    end
end

function m:entity_remove()
    for _, prefab in evObjectDetach:unpack() do
        if isValidReference(prefab) then
            w:sync("prefab:in", prefab)
            for _, entity in ipairs(prefab.entities) do
                if isValidReference(entity) then
                    w:remove_reference(entity)
                end
            end
            w:remove(prefab)
        end
    end
end
