local mgr = require 'new-debugger.mgr'
local event = {}

function event.initialized()
    mgr.sendToClient {
        type = 'event',
        seq = mgr.newSeq(),
        event = 'initialized',
    }
end

function event.capabilities()
    mgr.sendToClient {
        type = 'event',
        seq = mgr.newSeq(),
        event = 'capabilities',
        body = {
            capabilities = {
                supportsConfigurationDoneRequest = true,
            }
        }
    }
end

function event.stopped(threadId, msg)
    mgr.sendToClient {
        type = 'event',
        seq = mgr.newSeq(),
        event = 'stopped',
        body = {
            reason = msg,
            threadId = threadId,
        }
    }
end

function event.breakpoint(reason, breakpoint)
    mgr.sendToClient {
        type = 'event',
        seq = mgr.newSeq(),
        event = 'breakpoint',
        body = {
            reason = reason,
            breakpoint = breakpoint,
        }
    }
end

return event
