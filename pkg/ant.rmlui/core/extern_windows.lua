local environment = require "core.environment"
local document_manager = require "core.document_manager"

local CMD = {}

function CMD.open(extern_window, url, ...)
    assert(extern_window.document == nil)
    local doc = document_manager.open(url, extern_window.name, ...)
    if doc then
        extern_window.document = doc
        document_manager.onload(doc)
    end
end

function CMD.close(extern_window)
    local document = extern_window.document
    if document then
        local globals = environment[document]
        if globals then
            local window = globals.window
            window.close()
        end
        extern_window.document = nil
    end
end

local extern_windows = {}

local m = {}

function m.push(cmd, name, ...)
    local extern_window = extern_windows[name]
    if not extern_window then
        extern_window = {
            name = name,
            queue = {{cmd, ...}},
        }
        extern_windows[name] = extern_window
    else
        table.insert(extern_window.queue, {cmd, ...})
    end
    if extern_window.pending then
        return
    end
    extern_window.pending = true
    while true do
        local msg = table.remove(extern_window.queue, 1)
        if not msg then
            break
        end
        local f = CMD[msg[1]]
        f(extern_window, table.unpack(msg, 2))
    end
    extern_window.pending = nil
end

return m
