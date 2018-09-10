local status = require 'debugger.host.status'
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
        if frame.source and frame.source.path then
            ev.emit('stop-position', frame.source.path, frame.line)
        else
            -- TODO
        end
    end
end

function m.threads(pkg)
    status.threads = pkg.threads
end

function m.continue(pkg)
    ev.emit('run')
end

return m
