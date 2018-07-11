local mgr = require 'new-debugger.master.mgr'

local response = {}

function response.error(req, msg)
    mgr.sendToClient {
        type = 'response',
        seq = mgr.newSeq(),
        command = req.command,
        request_seq = req.seq,
        success = false,
        message = msg,
    }
end

function response.success(req, body)
    mgr.sendToClient {
        type = 'response',
        seq = mgr.newSeq(),
        command = req.command,
        request_seq = req.seq,
        success = true,
        body = body,
    }
end

function response.initialize(req)
    if req.__norepl then
        mgr.newSeq()
        return
    end
    mgr.sendToClient {
        type = 'response',
        seq = mgr.newSeq(),
        command = req.command,
        request_seq = req.seq,
        success = true,
        body = {
            supportsConfigurationDoneRequest = true,
            --supportsSetVariable = true,
            supportsConditionalBreakpoints = true,
            supportsHitConditionalBreakpoints = true,
            supportsDelayedStackTraceLoading = true,
            --supportsExceptionInfoRequest = true,
            supportsLogPoints = true,
            --supportsEvaluateForHovers = true,
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
        },
    }
end

function response.threads(req, threads)
    local thds = {}
    for _, id in ipairs(threads) do
        thds[#thds + 1] = {
            name = ('Thread %d'):format(id),
            id = id,
        }
    end
    mgr.sendToClient {
        type = 'response',
        seq = mgr.newSeq(),
        command = req.command,
        request_seq = req.seq,
        success = true,
        body = {
            threads = thds
        },
    }
end

return response
