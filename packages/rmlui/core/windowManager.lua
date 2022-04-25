local environment = require "core.environment"
local contextManager = require "core.contextManager"
local event = require "core.event"
local task = require "core.task"
local ltask = require "ltask"

local m = {}

local documents = {}
local names = {}

local function find_window(name)
    local document = documents[name]
    if document then
        local globals = environment[document]
        if globals then
            return globals.window
        end
    end
end

function m.open(name, url)
    local doc = contextManager.open(url)
    if doc then
        documents[name] = doc
        names[doc] = name
        contextManager.onload(doc)
    end
end

function m.close(name)
    local window = find_window(name)
    if window then
        window.close()
        documents[name] = nil
    end
end

function m.postMessage(name, data)
    local window = find_window(name)
    if window then
        window.postMessage(data)
    end
end

function m.postExternMessage(document, data)
    local name = names[document]
    if name then
        task.new(function ()
            ltask.send(ServiceWorld, "message", "rmlui", name, data)
        end)
    end
end

function event.OnDocumentDestroy(document)
    names[document] = nil
end

return m
