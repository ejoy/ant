local ecs = ...
local world = ecs.world
local w = world.w

local m = ecs.system "prefab_system"

local evObjectCreate = world:sub {"object_create"}
local evObjectMessage = world:sub {"object_message"}

local events = {
    message = {},
    update = {},
}

function m:entity_init()
    for _, event, ref in evObjectCreate:unpack() do
        if event.init then
            event.init(ref)
        end
        local message = event.message
        local update = event.update
        if message then
            events.message[event] = function (...) return message(ref, ...) end
        end
        if update then
            events.update[#events.update+1] = function () return update(ref) end
        end
    end
end

function m:data_changed()
    for msg in evObjectMessage:each() do
        local event = msg[2]
        events.message[event](table.unpack(msg, 3))
    end
    for _, update in ipairs(events.update) do
        update()
    end
end

function m:entity_remove()
end
