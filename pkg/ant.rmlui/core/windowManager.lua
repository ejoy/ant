local environment = require "core.environment"
local document_manager = require "core.document_manager"
local event = require "core.event"
local task = require "core.task"
local ltask = require "ltask"

local m = {}

local documents = {}
local names = {}
local messages = {}

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
    assert(documents[name] == nil)
    local doc = document_manager.open(url)
    if doc then
        documents[name] = doc
        names[doc] = name
        document_manager.onload(doc)
        local msgs = messages[name]
        if msgs then
            messages[name] = nil
            local window = find_window(name)
            if window then
                for _, data in ipairs(msgs) do
                    window.postMessage(data)
                end
            end
        end
    end
end

function m.close(name)
    messages[name] = nil
    local window = find_window(name)
    if window then
        window.close()
        documents[name] = nil
    end
end

function m.postMessage(name, data)
    if not documents[name] then
        if messages[name] then
            table.insert(messages[name], data)
        else
            messages[name] = { data }
        end
        return
    end
    local window = find_window(name)
    if window then
        window.postMessage(data)
    end
end

function m.postExternMessage(document, data)
    local name = names[document]
    if name then
        task.new(function ()
            ltask.send(ServiceWorld, "rmlui_message", name, data)
        end)
    end
end

function event.OnDocumentDestroy(document)
    names[document] = nil
end

return m
