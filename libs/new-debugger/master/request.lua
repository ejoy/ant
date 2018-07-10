local mgr = require 'new-debugger.master.mgr'
local response = require 'new-debugger.master.response'
local event = require 'new-debugger.master.event'

local request = {}

local initProto = {}

function request.initialize(req)
    if not mgr.isState 'birth' then
        response.error(req, 'already initialized')
        return false
    end
    response.initialize(req)
    mgr.setState 'initialized'
    event.initialized()
    event.capabilities()
    return false
end

function request.attach(req)
    initProto = {}
    if not mgr.isState 'initialized' then
        response.error(req, 'not initialized or unexpected state')
        return false
    end
    response.success(req)
    initProto = req
    return false
end

function request.configurationDone(req)
    response.success(req)
    local args = initProto.arguments
    if not args then
        return false
    end
    local stopOnEntry = true
    if type(args.stopOnEntry) == 'boolean' then
        stopOnEntry = args.stopOnEntry
    end
    if stopOnEntry then
        mgr.broadcastToWorker {
            cmd = 'stop',
            reason = 'stepping',
        }
    end
    return not stopOnEntry
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
    end
    response.success(req, {
        breakpoints = args.breakpoints
    })
    mgr.broadcastToWorker {
        cmd = 'setBreakpoints',
        source = args.source,
        breakpoints = args.breakpoints,
    }
    return false
end

function request.setExceptionBreakpoints(req)
    response.success(req)
    -- TODO
    return false
end

function request.stackTrace(req)
    local args = req.arguments
    if type(args.threadId) ~= 'number' then
        response.error(req, "Not found thread")
        return false
    end
    local threadId = args.threadId
    if not mgr.hasThread(threadId) then
        response.error(req, "Not found thread")
        return false
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
    return false
end

function request.scopes(req)
    local args = req.arguments
    if type(args.frameId) ~= 'number' then
        response.error(req, "Not found frame")
        return false
    end
    
	local threadAndFrameId = args.frameId
    local threadId = threadAndFrameId >> 16
    local frameId = threadAndFrameId & 0xFFFF
    if not mgr.hasThread(threadId) then
        response.error(req, "Not found thread")
        return false
    end
    
    mgr.sendToWorker(threadId, {
        cmd = 'scopes',
        command = req.command,
        seq = req.seq,
        frameId = frameId,
    })
    return false
end

function request.variables(req)
    local args = req.arguments
    local valueId = args.variablesReference
    local threadId = valueId >> 32
    local frameId = (valueId >> 16) & 0xFFFF
    if not mgr.hasThread(threadId) then
        response.error(req, "Not found thread")
        return false
    end
    
    mgr.sendToWorker(threadId, {
        cmd = 'variables',
        command = req.command,
        seq = req.seq,
        frameId = frameId,
        valueId = valueId & 0xFFFF,
    })
    return false
end

function request.evaluate(req)
    response.success(req)
    return false
end

function request.threads(req)
    response.threads(req, mgr.threads())
    return false
end

function request.disconnect(req)
    response.success(req)
    -- TODO
    return false
end

function request.pause(req)
    local args = req.arguments
    if type(args.threadId) ~= 'number' then
        response.error(req, "Not found thread")
        return false
    end
    local threadId = args.threadId
    if not mgr.hasThread(threadId) then
        response.error(req, "Not found thread")
        return false
    end

    mgr.sendToWorker(threadId, {
        cmd = 'stop',
        reason = 'stepping',
    })
    response.success(req)
    return false
end

function request.continue(req)
    local args = req.arguments
    if type(args.threadId) ~= 'number' then
        response.error(req, "Not found thread")
        return false
    end
    local threadId = args.threadId
    if not mgr.hasThread(threadId) then
        response.error(req, "Not found thread")
        return false
    end

    mgr.sendToWorker(threadId, {
        cmd = 'run',
    })
    response.success(req)
    return false
end

function request.next(req)
    local args = req.arguments
    if type(args.threadId) ~= 'number' then
        response.error(req, "Not found thread")
        return false
    end
    local threadId = args.threadId
    if not mgr.hasThread(threadId) then
        response.error(req, "Not found thread")
        return false
    end

    mgr.sendToWorker(threadId, {
        cmd = 'stepOver',
    })
    response.success(req)
    return false
end

function request.stepOut(req)
    local args = req.arguments
    if type(args.threadId) ~= 'number' then
        response.error(req, "Not found thread")
        return false
    end
    local threadId = args.threadId
    if not mgr.hasThread(threadId) then
        response.error(req, "Not found thread")
        return false
    end

    mgr.sendToWorker(threadId, {
        cmd = 'stepOut',
    })
    response.success(req)
    return false
end

function request.stepIn(req)
    local args = req.arguments
    if type(args.threadId) ~= 'number' then
        response.error(req, "Not found thread")
        return false
    end
    local threadId = args.threadId
    if not mgr.hasThread(threadId) then
        response.error(req, "Not found thread")
        return false
    end

    mgr.sendToWorker(threadId, {
        cmd = 'stepIn',
    })
    response.success(req)
    return false
end

function request.source(req)
    local args = req.arguments
    local threadId = args.sourceReference >> 32
    if not mgr.hasThread(threadId) then
        response.error(req, "Not found thread " .. threadId)
        return false
    end
    local sourceReference = args.sourceReference & 0xFFFFFFFF
    mgr.sendToWorker(threadId, {
        cmd = 'source',
        command = req.command,
        seq = req.seq,
        sourceReference = sourceReference,
    })
    return false
end

return request
