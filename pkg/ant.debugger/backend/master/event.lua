local mgr = require 'backend.master.mgr'
local event = {}

function event.initialized()
    mgr.clientSend {
        type = 'event',
        seq = mgr.newSeq(),
        event = 'initialized',
    }
end

function event.capabilities()
    mgr.clientSend {
        type = 'event',
        seq = mgr.newSeq(),
        event = 'capabilities',
        body = {
            capabilities = require 'common.capabilities'
        }
    }
end

function event.stopped(body)
    mgr.clientSend {
        type = 'event',
        seq = mgr.newSeq(),
        event = 'stopped',
        body = body
    }
end

function event.breakpoint(body)
    mgr.clientSend {
        type = 'event',
        seq = mgr.newSeq(),
        event = 'breakpoint',
        body = body
    }
end

function event.output(body)
    mgr.clientSend {
        type = 'event',
        seq = mgr.newSeq(),
        event = 'output',
        body = body
    }
end

function event.terminated()
    mgr.clientSend {
        type = 'event',
        seq = mgr.newSeq(),
        event = 'terminated',
        body = {
            restart = false,
        }
    }
end

function event.loadedSource(body)
    mgr.clientSend {
        type = 'event',
        seq = mgr.newSeq(),
        event = 'loadedSource',
        body = body
    }
end

function event.thread(body)
    mgr.clientSend {
        type = 'event',
        seq = mgr.newSeq(),
        event = 'thread',
        body = body
    }
end

function event.invalidated(body)
    if not mgr.getClient().supportsInvalidatedEvent then
        return
    end
    mgr.clientSend {
        type = 'event',
        seq = mgr.newSeq(),
        event = 'invalidated',
        body = body
    }
end

function event.continued(body)
    mgr.clientSend {
        type = 'event',
        seq = mgr.newSeq(),
        event = 'continued',
        body = body
    }
end

function event.memory(body)
    mgr.clientSend {
        type = 'event',
        seq = mgr.newSeq(),
        event = 'memory',
        body = body
    }
end

return event
