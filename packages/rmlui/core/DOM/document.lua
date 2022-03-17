local rmlui = require "rmlui"
local event = require "core.event"
local createElement = require "core.DOM.element"

local function constructor(handle)
    local mt = {}
    mt.__index = mt
    function mt.getElementById(id)
        return createElement(rmlui.DocumentGetElementById(handle, id), handle)
    end
    function mt.createElement(tag)
        return createElement(rmlui.DocumentCreateElement(handle, tag), handle, true)
    end
    function mt.createTextNode(text)
        return createElement(rmlui.DocumentCreateTextNode(handle, text), handle, true)
    end
    return setmetatable({_handle = handle}, mt)
end

local pool = {}

function event.OnDocumentCreate(document, globals)
    local o = constructor(document)
    globals.document = o
    pool[document] = o
end

function event.OnDocumentDestroy(handle)
    pool[handle] = nil
end

return function (handle)
    if handle == nil then
        return
    end
    return pool[handle]
end
