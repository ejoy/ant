local status = require 'debugger.host.status'
local request = require 'debugger.host.request'
local ev = require 'debugger.event'

local m = {}

function m.initialize(pkg)
    for k, v in pairs(pkg) do
        status.capabilities[k] = v
    end
end

function m.stackTrace(pkg)
    if pkg.stackFrames and pkg.stackFrames[1] then
        local frame = pkg.stackFrames[1]
        local source = frame.source
        if source then
            ev.emit('host-stopped', source, frame.line)
        end
    end
end

function m.threads(pkg)
    status.threads = pkg.threads
end

function m.continue(pkg)
    ev.emit('host-running')
end

return m
