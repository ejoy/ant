local mgr = require 'new-debugger.mgr'
local response = require 'new-debugger.response'
local event = require 'new-debugger.event'

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

function request.setBreakpoints(req)
    response.success(req)
    -- TODO
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
    
    -- TODO
    response.success(req, {
        scopes = { }
    }) 
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

return request
