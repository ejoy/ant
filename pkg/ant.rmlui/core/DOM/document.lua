local rmlui = require "rmlui"
local event = require "core.event"
local constructor = require "core.DOM.constructor"

local function constructorDocument(handle)
    local doc = {_handle = handle}
    local body = constructor.Element(handle, false, rmlui.DocumentGetBody(handle))
    function doc.getBody()
        return body
    end
    function doc.getElementById(id)
        return body.getElementById(id)
    end
    function doc.getElementsByTagName(tag_name)
        return body.getElementsByTagName(tag_name)
    end
    function doc.getElementsByClassName(class_name)
        return body.getElementsByClassName(class_name)
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
