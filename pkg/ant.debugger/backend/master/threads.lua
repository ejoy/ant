local mgr = require 'backend.master.mgr'
local event = require 'backend.master.event'
local response = require 'backend.master.response'

local CMD = {}

function CMD.initWorker(WorkerIdent)
    mgr.initWorker(WorkerIdent)
end

function CMD.exitWorker(w)
    mgr.exitWorker(w)
end

function CMD.eventStop(w, req)
    req.threadId = w
    event.stopped(req)
end

function CMD.eventBreakpoint(_, req)
    event.breakpoint(req)
end

function CMD.eventOutput(w, req)
    if req.variablesReference then
        req.variablesReference = (w << 24) | req.variablesReference
    end
    event.output(req)
end

function CMD.eventThread(w, req)
    req.threadId = w
    if req.reason == "started" then
        mgr.setThreadStatus(w, "connect")
    elseif req.reason == "exited" then
        mgr.setThreadStatus(w, "disconnect")
    end
    event.thread(req)
end

function CMD.eventInvalidated(w, req)
    req.threadId = w
    event.invalidated(req)
end

function CMD.eventLoadedSource(w, req)
    if req.source and req.source.sourceReference then
        req.source.sourceReference = (w << 32) | req.source.sourceReference
    end
    event.loadedSource(req)
end

function CMD.stackTrace(w, req)
    if not req.success then
        response.error(req, req.message)
        return
    end
    for _, frame in ipairs(req.body.stackFrames) do
        frame.id = (w << 24) | frame.id
        if frame.source and frame.source.sourceReference then
            frame.source.sourceReference = (w << 32) | frame.source.sourceReference
        end
    end
    response.success(req, req.body)
end

function CMD.evaluate(w, req)
    if not req.success then
        response.error(req, req.message)
        return
    end
    if req.body.variablesReference then
        req.body.variablesReference = (w << 24) | req.body.variablesReference
    else
        req.body.variablesReference = 0
    end
    response.success(req, req.body)
end

function CMD.source(_, req)
    if not req.content then
        response.success(req, {
            content = 'Source not available',
            mimeType = 'text/x-lua',
        })
        return
    end
    response.success(req, {
        content = req.content,
        mimeType = 'text/x-lua',
    })
end

function CMD.scopes(w, req)
    for _, scope in ipairs(req.body.scopes) do
        if scope.variablesReference then
            scope.variablesReference = (w << 24) | scope.variablesReference
        else
            scope.variablesReference = 0
        end
    end
    response.success(req, req.body)
end

function CMD.variables(w, req)
    if not req.success then
        response.error(req, req.message)
        return
    end
    for _, var in ipairs(req.body.variables) do
        if var.variablesReference then
            var.variablesReference = (w << 24) | var.variablesReference
        else
            var.variablesReference = 0
        end
        if var.memoryReference then
            var.memoryReference = "memory_" .. w .. "x" .. var.memoryReference
        end
    end
    response.success(req, req.body)
end

function CMD.exceptionInfo(_, req)
    response.success(req, req.body)
end

function CMD.setVariable(_, req)
    if not req.success then
        response.error(req, req.message)
        return
    end
    response.success(req, req.body)
end

function CMD.readMemory(_, req)
    if not req.success then
        response.error(req, req.message)
        return
    end
    response.success(req, req.body)
end

function CMD.writeMemory(_, req)
    if not req.success then
        response.error(req, req.message)
        return
    end
    response.success(req, req.body)
end

function CMD.eventMemory(w, req)
    req.memoryReference = "memory_" .. w .. "x" .. req.memoryReference
    event.memory(req)
end

function CMD.setExpression(_, req)
    if not req.success then
        response.error(req, req.message)
        return
    end
    response.success(req, req.body)
end

function CMD.setThreadName(w, name)
    mgr.setThreadName(w, name)
end

return CMD
