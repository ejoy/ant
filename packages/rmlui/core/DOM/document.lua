local rmlui = require "rmlui"
local event = require "core.event"
local constructorElement = require "core.DOM.element"
local constructorTextNode = require "core.DOM.text"

local function constructor(handle)
    local doc = {_handle = handle}
    function doc.getElementById(id)
        return constructorElement(handle, false, rmlui.DocumentGetElementById(handle, id))
    end
    function doc.createElement(tag)
        return constructorElement(handle, true, rmlui.DocumentCreateElement(handle, tag))
    end
    function doc.createTextNode(text)
        return constructorTextNode(handle, true, rmlui.DocumentCreateTextNode(handle, text))
    end
    function doc.elementFromPoint(x, y)
        return constructorElement(handle, false, rmlui.DocumentElementFromPoint(handle, x, y))
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
