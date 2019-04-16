local mgr = require 'backend.master.mgr'
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
            capabilities = require 'common.capabilities'
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

function event.output(category, output, source, line)
    mgr.sendToClient {
        type = 'event',
        seq = mgr.newSeq(),
        event = 'output',
        body = {
            category = category,
            output = output,
            source = source,
            line = line,
        }
    }
end

function event.terminated()
    mgr.sendToClient {
        type = 'event',
        seq = mgr.newSeq(),
        event = 'terminated',
        body = {
            restart = false,
        }
    }
end

function event.loadedSource(reason, source)
    mgr.sendToClient {
        type = 'event',
        seq = mgr.newSeq(),
        event = 'loadedSource',
        body = {
            reason = reason,
            source = source,
        }
    }
end

return event
