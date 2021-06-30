local event = require "core.event"
local task = require "core.task"
local ltask = require "ltask"

local names = {}

function event.OnDocumentExternName(document, nameordoc)
    if type(nameordoc) == "string" then
        names[document] = nameordoc
    else
        names[document] = names[nameordoc]
    end
end

function event.OnDocumentDestroy(document)
    names[document] = nil
end

return function (document)
    local m = {}
    function m.postMessage(data)
        local name = names[document]
        task.new(function ()
            ltask.send(ServiceWorld, "message", "rmlui", name, data)
        end)
    end
    return m
end
