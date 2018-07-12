local mgr = require 'new-debugger.master.mgr'
local event = {}

event._capabilities = {
    supportsConfigurationDoneRequest = true,
    --supportsSetVariable = true,
    supportsConditionalBreakpoints = true,
    supportsHitConditionalBreakpoints = true,
    supportsDelayedStackTraceLoading = true,
    supportsExceptionInfoRequest = true,
    supportsLogPoints = true,
    supportsEvaluateForHovers = true,
    --exceptionBreakpointFilters = {
    --    {
    --        default = false,
    --        filter = 'pcall',
    --        label = 'Exception: Lua pcall',
    --    },
    --    {
    --        default = false,
    --        filter = 'xpcall',
    --        label = 'Exception: Lua xpcall',
    --    },
    --    {
    --        default = true,
    --        filter = 'lua_pcall',
    --        label = 'Exception: C lua_pcall',
    --    },
    --    {
    --        default = true,
    --        filter = 'lua_panic',
    --        label = 'Exception: C lua_panic',
    --    }
    --}
}

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
            capabilities = event._capabilities
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
            column = line and 1 or nil,
        }
    }
end

return event
