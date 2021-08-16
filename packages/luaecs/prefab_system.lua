local ecs = ...
local world = ecs.world
local w = world.w

local m = ecs.system "prefab_system"

local evObjectCreate = world:sub {"object_create"}
local evObjectMessage = world:sub {"object_message"}
local evObjectRemove = world:sub {"object_remove"}

local eventUpdate = {}
local eventMessage = {}

local refs = {}

function m:entity_init()
    for _, event, ref in evObjectCreate:unpack() do
        if event.init then
            event.init(ref)
        end
        local message = event.message
        local update = event.update
        local remove = event.remove
        if message or update or remove then
            refs[event] = ref
        end
        if message then
            eventMessage[event] = function (...) return message(ref, ...) end
        end
        if update then
            eventUpdate[event] = function () return update(ref) end
        end
    end
end

function m:data_changed()
    for msg in evObjectMessage:each() do
        local event = msg[2]
        eventMessage[event](table.unpack(msg, 3))
    end
    for _, update in pairs(eventUpdate) do
        update()
    end
end

local function object_remove(event)
    local ref = refs[event]
    if event.remove then
        event.remove(ref)
    end
    for _, v in pairs(ref) do
        w:remove(v)
    end
    refs[event] = nil
    eventUpdate[event] = nil
    eventMessage[event] = nil
end

function m:entity_remove()
    for _, event in evObjectRemove:unpack() do
        object_remove(event)
    end
end
