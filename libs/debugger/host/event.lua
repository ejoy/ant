local request = require 'debugger.host.request'
local status = require 'debugger.host.status'

local m = {}

function m.initialized()
    if status.capabilities.supportsConfigurationDoneRequest then
        request.configurationDone()
    end
    request.threads()
end

function m.stopped(pkg)
    local threadId = pkg.threadId
    status.threadId = threadId
    status.status = 'stopped'
    request.threads()
    request.stackTrace(threadId, 0, 20)
end

return m
