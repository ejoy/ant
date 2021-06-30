local rmlui = require "rmlui"
local event = require "core.event"
local m = {}
local context

function event.OnContextChange(c)
    context = c
end

function m.open(url)
    if context then
        local document = rmlui.ContextLoadDocument(context, url)
        if document then
            rmlui.DocumentShow(document)
            return document
        end
    end
end

function m.close(document)
    rmlui.ContextUnloadDocument(context, document)
end

return m
