local rmlui = require "rmlui"
local event = require "core.event"
local constructor = require "core.DOM.constructor"

local function constructorDocument(handle)
    local doc = {_handle = handle}
    function doc.getElementById(id)
        return constructor.Element(handle, false, rmlui.DocumentGetElementById(handle, id))
    end
    function doc.createElement(tag)
        return constructor.Element(handle, true, rmlui.DocumentCreateElement(handle, tag))
    end
    function doc.createTextNode(text)
        return constructor.Text(handle, true, rmlui.DocumentCreateTextNode(handle, text))
    end
    function doc.elementFromPoint(x, y)
        return constructor.Element(handle, false, rmlui.DocumentElementFromPoint(handle, x, y))
    end
    return doc
end

local pool = {}

function event.OnDocumentCreate(document, globals)
    local o = constructorDocument(document)
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
