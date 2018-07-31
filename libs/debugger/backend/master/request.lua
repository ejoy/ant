local mgr = require 'debugger.backend.master.mgr'
local response = require 'debugger.backend.master.response'
local event = require 'debugger.backend.master.event'
local ev = require 'debugger.event'

local request = {}

local stopOnEntry = true
local config = nil
local readyTrg = nil

function request.initialize(req)
    if not mgr.isState 'birth' then
        response.error(req, 'already initialized')
        return
    end
    response.initialize(req)
    mgr.setState 'initialized'
    event.initialized()
    event.capabilities()
end

function request.attach(req)
    initProto = {}
    if not mgr.isState 'initialized' then
        response.error(req, 'not initialized or unexpected state')
        return
    end
    response.success(req)

    config = req.arguments
    stopOnEntry = true
    if type(config.stopOnEntry) == 'boolean' then
        stopOnEntry = config.stopOnEntry
    end

    mgr.broadcastToWorker {
        cmd = 'initializing',
        config = config,
    }
    
    if readyTrg then
        readyTrg:remove()
        readyTrg = nil
    end
    readyTrg = ev.on('worker-ready', function(w)
        mgr.sendToWorker(w, {
            cmd = 'initialized',
            config = config,
        })
    end)
end

function request.launch(req)
    return request.attach(req)
end

function request.configurationDone(req)
    response.success(req)
    if stopOnEntry then
        mgr.broadcastToWorker {
            cmd = 'stop',
            reason = 'stepping',
        }
    end
    mgr.broadcastToWorker {
        cmd = 'initialized',
    }
end

local breakpointID = 0
local function genBreakpointID()
    breakpointID = breakpointID + 1
    return breakpointID
end

function request.setBreakpoints(req)
    local args = req.arguments
    for _, bp in ipairs(args.breakpoints) do
        bp.id = genBreakpointID()
        bp.verified = false
    end
    response.success(req, {
        breakpoints = args.breakpoints
    })
    if args.source.sourceReference then
        args.source.sourceReference = args.source.sourceReference & 0xffffffff
    end
    mgr.broadcastToWorker {
        cmd = 'setBreakpoints',
        source = args.source,
        breakpoints = args.breakpoints,
    }
end

function request.setExceptionBreakpoints(req)
    local args = req.arguments
    if type(args.filters) == 'table' then
        mgr.broadcastToWorker {
            cmd = 'setExceptionBreakpoints',
            filters = args.filters,
        }
    end
    response.success(req)
end

function request.stackTrace(req)
    local args = req.arguments
    if type(args.threadId) ~= 'number' then
        response.error(req, "Not found thread")
        return
    end
    local threadId = args.threadId
    if not mgr.hasThread(threadId) then
        response.error(req, "Not found thread")
        return
    end

    local levels = args.levels and args.levels or 200
    levels = levels ~= 0 and levels or 200
    local startFrame = args.startFrame and args.startFrame or 0
    local endFrame = startFrame + levels

    mgr.sendToWorker(threadId, {
        cmd = 'stackTrace',
        command = req.command,
        seq = req.seq,
        startFrame = startFrame,
        endFrame = endFrame,
    })
end

function request.scopes(req)
    local args = req.arguments
    if type(args.frameId) ~= 'number' then
        response.error(req, "Not found frame")
        return
    end

    local threadAndFrameId = args.frameId
    local threadId = threadAndFrameId >> 16
    local frameId = threadAndFrameId & 0xFFFF
    if not mgr.hasThread(threadId) then
        response.error(req, "Not found thread")
        return
    end

    mgr.sendToWorker(threadId, {
        cmd = 'scopes',
        command = req.command,
        seq = req.seq,
        frameId = frameId,
    })
end

function request.variables(req)
    local args = req.arguments
    local valueId = args.variablesReference
    local threadId = valueId >> 32
    local frameId = (valueId >> 16) & 0xFFFF
    if not mgr.hasThread(threadId) then
        response.error(req, "Not found thread")
        return
    end

    mgr.sendToWorker(threadId, {
        cmd = 'variables',
        command = req.command,
        seq = req.seq,
        frameId = frameId,
        valueId = valueId & 0xFFFF,
    })
end

function request.evaluate(req)
    local args = req.arguments
    if type(args.frameId) ~= 'number' then
        response.error(req, "Not found frame")
        return
    end
    if type(args.expression) ~= 'string' then
        response.error(req, "Error expression")
        return
    end
    local threadAndFrameId = args.frameId
    local threadId = threadAndFrameId >> 16
    local frameId = threadAndFrameId & 0xFFFF
    if not mgr.hasThread(threadId) then
        response.error(req, "Not found thread")
        return
    end
    mgr.sendToWorker(threadId, {
        cmd = 'evaluate',
        command = req.command,
        seq = req.seq,
        frameId = frameId,
        context = args.context,
        expression = args.expression,
    })
end

function request.threads(req)
    response.threads(req, mgr.threads())
end

function request.disconnect(req)
    response.success(req)
    mgr.broadcastToWorker {
        cmd = 'terminated',
    }
    if readyTrg then
        readyTrg:remove()
        readyTrg = nil
    end
    mgr.setState 'terminated'
    event.terminated()
    mgr.close()
    return true
end

function request.pause(req)
    local args = req.arguments
    if type(args.threadId) ~= 'number' then
        response.error(req, "Not found thread")
        return
    end
    local threadId = args.threadId
    if not mgr.hasThread(threadId) then
        response.error(req, "Not found thread")
        return
    end

    mgr.sendToWorker(threadId, {
        cmd = 'stop',
        reason = 'stepping',
    })
    response.success(req)
end

function request.continue(req)
    local args = req.arguments
    if type(args.threadId) ~= 'number' then
        response.error(req, "Not found thread")
        return
    end
    local threadId = args.threadId
    if not mgr.hasThread(threadId) then
        response.error(req, "Not found thread")
        return
    end

    mgr.sendToWorker(threadId, {
        cmd = 'run',
    })
    response.success(req)
end

function request.next(req)
    local args = req.arguments
    if type(args.threadId) ~= 'number' then
        response.error(req, "Not found thread")
        return
    end
    local threadId = args.threadId
    if not mgr.hasThread(threadId) then
        response.error(req, "Not found thread")
        return
    end

    mgr.sendToWorker(threadId, {
        cmd = 'stepOver',
    })
    response.success(req)
end

function request.stepOut(req)
    local args = req.arguments
    if type(args.threadId) ~= 'number' then
        response.error(req, "Not found thread")
        return
    end
    local threadId = args.threadId
    if not mgr.hasThread(threadId) then
        response.error(req, "Not found thread")
        return
    end

    mgr.sendToWorker(threadId, {
        cmd = 'stepOut',
    })
    response.success(req)
end

function request.stepIn(req)
    local args = req.arguments
    if type(args.threadId) ~= 'number' then
        response.error(req, "Not found thread")
        return
    end
    local threadId = args.threadId
    if not mgr.hasThread(threadId) then
        response.error(req, "Not found thread")
        return
    end

    mgr.sendToWorker(threadId, {
        cmd = 'stepIn',
    })
    response.success(req)
end

function request.source(req)
    local args = req.arguments
    local threadId = args.sourceReference >> 32
    if not mgr.hasThread(threadId) then
        response.error(req, "Not found thread " .. threadId)
        return
    end
    local sourceReference = args.sourceReference & 0xFFFFFFFF
    mgr.sendToWorker(threadId, {
        cmd = 'source',
        command = req.command,
        seq = req.seq,
        sourceReference = sourceReference,
    })
end

function request.exceptionInfo(req)
    local args = req.arguments
    local threadId = args.threadId
    if not mgr.hasThread(threadId) then
        response.error(req, "Not found thread " .. threadId)
        return
    end
    mgr.sendToWorker(threadId, {
        cmd = 'exceptionInfo',
        command = req.command,
        seq = req.seq,
    })
end

function request.setVariable(req)
    local args = req.arguments
    local valueId = args.variablesReference
    local threadId = valueId >> 32
    local frameId = (valueId >> 16) & 0xFFFF
    if not mgr.hasThread(threadId) then
        response.error(req, "Not found thread")
        return
    end
    mgr.sendToWorker(threadId, {
        cmd = 'setVariable',
        command = req.command,
        seq = req.seq,
        frameId = frameId,
        valueId = valueId & 0xFFFF,
        name = args.name,
        value = args.value,
    })
end

return request
