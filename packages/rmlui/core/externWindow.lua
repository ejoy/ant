local event = require "core.event"
local thread = require "thread"
local channel = thread.channel_produce "rmlui_res"

local names = {}

function event.OnDocumentExternName(document, nameordoc)
    if type(nameordoc) == "string" then
        names[document] = nameordoc
    else
        names[document] = names[nameordoc]
    end
end

function event.OnDeleteDocument(document)
    names[document] = nil
end

return function (document)
    local m = {}
    function m.postMessage(data)
        channel("message", names[document], data)
    end
    return m
end
