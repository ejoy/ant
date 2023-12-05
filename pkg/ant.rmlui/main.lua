if not ServiceWorld then
    error "It can only be imported in rmlui service."
end

local document_manager = require "core.document_manager"
local constructor = require "core.DOM.constructor"

local m = {}

function m.openWindow(url)
    local newdoc = document_manager.open(url)
    if not newdoc then
        return
    end
    document_manager.onload(newdoc)
    return constructor.Window(newdoc)
end

return m
