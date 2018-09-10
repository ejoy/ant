local request = require 'debugger.host.request'
local status = require 'debugger.host.status'

local m = {}

function m.stopped(pkg)
    local threadId = pkg.threadId
    status.threadId = threadId
    request.threads()
    request.stackTrace(threadId, 0, 20)
end

return m
