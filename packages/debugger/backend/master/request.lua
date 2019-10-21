local mgr = require 'backend.master.mgr'
local response = require 'backend.master.response'
local event = require 'backend.master.event'
local ev = require 'common.event'

local request = {}

local readyTrg = nil
local firstWorker = true
local initializing = false
local config = {
    initialize = {},
    breakpoints = {},
}

ev.on('close', function()
    if readyTrg then
        readyTrg:remove()
        readyTrg = nil
    end
    event.terminated()
end)

local function checkThreadId(req, threadId)
    if type(threadId) ~= 'number' then
        response.error(req, "No threadId")
        return
    end
    if not mgr.hasThread(threadId) then
        response.error(req, "Not found thread [" .. threadId .. "]")
        return
    end
    return true
end

function request.initialize(req)
    if not mgr.isState 'birth' then
        response.error(req, 'already initialized')
        return
    end
    firstWorker = true
    response.initialize(req)
    mgr.setState 'initialized'
    event.initialized()
    event.capabilities()
end

function request.attach(req)
    if not mgr.isState 'initialized' then
        response.error(req, 'not initialized or unexpected state')
        return
    end
    response.success(req)

    initializing = true
    config = {
        initialize = req.arguments,
        breakpoints = {},
    }
    mgr.termOnExit(req.arguments.termOnExit)
end

function request.launch(req)
    return request.attach(req)
end

local function tryStop(w)
    if firstWorker then
        firstWorker = false
        if not not config.initialize.stopOnEntry then
            mgr.sendToWorker(w, {
                cmd = 'stop',
                reason = 'entry',
            })
            return
        end
    end
    if not not config.initialize.stopOnThreadEntry then
        mgr.sendToWorker(w, {
            cmd = 'stop',
            reason = 'entry',
        })
    end
end

local function initializeWorker(w)
    mgr.sendToWorker(w, {
        cmd = 'initializing',
        config = config.initialize,
    })
    for _, bp in pairs(config.breakpoints) do
        mgr.sendToWorker(w, {
            cmd = 'setBreakpoints',
            source = bp[1],
            breakpoints = bp[2],
            content = bp[3],
        })
    end
    tryStop(w)
    mgr.sendToWorker(w, {
        cmd = 'initialized',
    })
end

function request.configurationDone(req)
    response.success(req)
    initializing = false

    if readyTrg then
        readyTrg:remove()
        readyTrg = nil
    end
    readyTrg = ev.on('worker-ready', function(w)
        initializeWorker(w)
    end)

    for _, w in ipairs(mgr.threads()) do
        initializeWorker(w)
    end
    mgr.initConfig(config)
end

local breakpointID = 0
local function genBreakpointID()
    breakpointID = breakpointID + 1
    return breakpointID
end

local function skipBOM(s)
    if not s then
        return
    end
    if s:sub(1,3) == "\xEF\xBB\xBF" then
        s = s:sub(4)
    end
    if s:sub(1,1) == "#" then
        local pos = s:find('\r\n', 2, true)
        s = pos and s:sub(pos+1) or s
    end
    return s
end

function request.setBreakpoints(req)
    local args = req.arguments
    local content = skipBOM(args.sourceContent)
    if args.source.path and args.source.path:sub(1,4) == "git:" then
        response.error(req, "Does not support git path.")
        return
    end
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
    --TODO path 无视大小写？
    config.breakpoints[args.source.sourceReference or args.source.path] = {
        args.source,
        args.breakpoints,
        content,
    }
    if not initializing then
        mgr.broadcastToWorker {
            cmd = 'setBreakpoints',
            source = args.source,
            breakpoints = args.breakpoints,
            content = content,
        }
    end
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
    local threadId = args.threadId
    if not checkThreadId(req, threadId) then
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
        response.error(req, "No frameId")
        return
    end

    local threadId = args.frameId >> 24
    local frameId = args.frameId & 0x00FFFFFF
    if not checkThreadId(req, threadId) then
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
    local threadId = args.variablesReference >> 24
    local valueId = args.variablesReference & 0x00FFFFFF
    if not checkThreadId(req, threadId) then
        return
    end
    mgr.sendToWorker(threadId, {
        cmd = 'variables',
        command = req.command,
        seq = req.seq,
        valueId = valueId,
        filter = args.filter,
        start = args.start,
        count = args.count,
    })
end

function request.evaluate(req)
    local args = req.arguments
    if type(args.frameId) ~= 'number' then
        response.error(req, "Please pause to evaluate expressions")
        return
    end
    if type(args.expression) ~= 'string' then
        response.error(req, "Error expression")
        return
    end
    local threadId = args.frameId >> 24
    local frameId = args.frameId & 0x00FFFFFF
    if not checkThreadId(req, threadId) then
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
    mgr.close()
    return true
end

function request.terminate(req)
    response.success(req)
    mgr.close()
    return true
end

function request.pause(req)
    local args = req.arguments
    local threadId = args.threadId
    if not checkThreadId(req, threadId) then
        return
    end
    mgr.sendToWorker(threadId, {
        cmd = 'stop',
        reason = 'pause',
    })
    response.success(req)
end

function request.continue(req)
    local args = req.arguments
    local threadId = args.threadId
    if not checkThreadId(req, threadId) then
        return
    end
    mgr.sendToWorker(threadId, {
        cmd = 'run',
    })
    response.success(req, {
        allThreadsContinued = false,
    })
end

function request.next(req)
    local args = req.arguments
    local threadId = args.threadId
    if not checkThreadId(req, threadId) then
        return
    end
    mgr.sendToWorker(threadId, {
        cmd = 'stepOver',
    })
    response.success(req)
end

function request.stepOut(req)
    local args = req.arguments
    local threadId = args.threadId
    if not checkThreadId(req, threadId) then
        return
    end
    mgr.sendToWorker(threadId, {
        cmd = 'stepOut',
    })
    response.success(req)
end

function request.stepIn(req)
    local args = req.arguments
    local threadId = args.threadId
    if not checkThreadId(req, threadId) then
        return
    end
    mgr.sendToWorker(threadId, {
        cmd = 'stepIn',
    })
    response.success(req)
end

function request.source(req)
    local args = req.arguments
    local threadId = args.sourceReference >> 24
    local sourceReference = args.sourceReference & 0x00FFFFFF
    if not checkThreadId(req, threadId) then
        return
    end
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
    if not checkThreadId(req, threadId) then
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
    local threadId = args.variablesReference >> 24
    local valueId = args.variablesReference & 0x00FFFFFF
    if not checkThreadId(req, threadId) then
        return
    end
    mgr.sendToWorker(threadId, {
        cmd = 'setVariable',
        command = req.command,
        seq = req.seq,
        valueId = valueId,
        name = args.name,
        value = args.value,
    })
end

function request.loadedSources(req)
    response.success(req, {
        sources = {}
    })
    mgr.broadcastToWorker {
        cmd = 'loadedSources'
    }
end

--function print(...)
--    local n = select('#', ...)
--    local t = {}
--    for i = 1, n do
--        t[i] = tostring(select(i, ...))
--    end
--    event.output('stdout', table.concat(t, '\t')..'\n')
--end

return request
