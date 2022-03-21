local rmlui = require "rmlui"
local event = require "core.event"
local createElement = require "core.DOM.element"

local function constructor(handle)
    local doc = {_handle = handle}
    function doc.getElementById(id)
        return createElement(rmlui.DocumentGetElementById(handle, id), handle)
    end
    function doc.createElement(tag)
        return createElement(rmlui.DocumentCreateElement(handle, tag), handle, true)
    end
    function doc.createTextNode(text)
        return createElement(rmlui.DocumentCreateTextNode(handle, text), handle, true)
    end
    return doc
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
