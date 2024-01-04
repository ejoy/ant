local rmlui = require "rmlui"
local event = require "core.event"
local constructor = require "core.DOM.constructor"

local m = {}

local E = {}

function m.add(document, element, type, func)
    local M = E[document][element]
    if not M then
        M = {}
        E[document][element] = M
    end
    local L = M[type]
    if not L then
        M[type] = {func}
    else
        L[#L+1] = func
    end
    return {type, func}
end

function m.remove(document, element, id)
    local M = E[document][element]
    if not M then
        return
    end
    if type(id) ~= "table" then
        M[id] = nil
        return
    end
    local type, func = id[1], id[2]
    local L = M[type]
    if not L then
        return
    end
    for i, v in ipairs(L) do
        if v == func then
            table.remove(L, i)
            break
        end
    end
end

local function table_append(t, a)
	table.move(a, 1, #a, #t+1, t)
end

function m.dispatch(document, element, type, eventData)
    local D = E[document]
    if not D then
        return
    end
    local listeners = {}
    local elements = {}
    local walk_element = element
    while walk_element do
        local M = D[walk_element]
        if M then
            local L = M[type]
            if L then
                table_append(listeners, L)
                local start = #elements
                local elementObject = constructor.Element(document, false, walk_element)
                for i = 1, #L do
                    elements[start+i] = elementObject
                end
            end
        end
        walk_element = rmlui.NodeGetParent(walk_element)
    end
    eventData.type = type
    eventData.target = constructor.Element(document, false, element)
    for i = 1, #listeners do
        local listener = listeners[i]
        eventData.current = elements[i]
        listener(eventData)
    end
end

function event.OnDestroyNode(document, node)
    local D = E[document]
    if D then
        D[node] = nil
    end
end

function event.OnDocumentCreate(document)
    E[document] = {}
end

function event.OnDocumentDestroy(document)
    E[document] = nil
end

return m
