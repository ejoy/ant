local constructor = require "core.DOM.constructor"
local contextManager = require "core.contextManager"
local event = require "core.event"

local m = {}

local windows = {}

function m.open(name, url)
    local doc = contextManager.open(url)
    if doc then
        windows[name] = constructor.Window(doc, "extern")
        event("OnDocumentExternName", doc, name)
        contextManager.onload(doc)
    end
end

function m.close(name)
    local window = windows[name]
    if window then
        window.close()
        windows[name] = nil
    end
end

function m.postMessage(name, data)
    local window = windows[name]
    if window then
        window.postMessage(data)
    end
end

return m
