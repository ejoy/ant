local event = require 'backend.master.event'
local response = require 'backend.master.response'
local ev = require 'backend.event'

local CMD = {}

function CMD.eventStop(w, req)
    event.stopped(w, req.reason)
end

function CMD.stackTrace(w, req)
    if not req.success then
        response.error(req, req.message)
        return
    end
    for _, frame in ipairs(req.stackFrames) do
        frame.id = (w << 24) | frame.id
        if frame.source and frame.source.sourceReference then
            frame.source.sourceReference = (w << 32) | frame.source.sourceReference
        end
    end
    response.success(req, {
        stackFrames = req.stackFrames,
        totalFrames = req.totalFrames,
    })
end

function CMD.evaluate(w, req)
    if not req.success then
        response.error(req, req.message)
        return
    end
    if req.body.variablesReference then
        req.body.variablesReference = (w << 24) | req.body.variablesReference
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
    for _, scope in ipairs(req.scopes) do
        scope.variablesReference = (w << 24) | scope.variablesReference
    end
    response.success(req, {
        scopes = req.scopes
    })
end

function CMD.variables(w, req)
    if not req.success then
        response.error(req, req.message)
        return
    end
    for _, var in ipairs(req.variables) do
        if var.variablesReference then
            var.variablesReference = (w << 24) | var.variablesReference
        end
    end
    response.success(req, {
        variables = req.variables
    })
end

function CMD.eventBreakpoint(_, req)
    event.breakpoint(req.reason, req.breakpoint)
end

function CMD.eventOutput(_, req)
    event.output(req.category, req.output, req.source, req.line)
end

function CMD.eventThread(w, req)
    ev.emit('thread', req.reason, w)
    event.thread(req.reason, w)
end

function CMD.exceptionInfo(_, req)
    response.success(req, {
        breakMode = req.breakMode,
        exceptionId = req.exceptionId,
        details = req.details,
    })
end

function CMD.setVariable(_, req)
    if not req.success then
        response.error(req, req.message)
        return
    end
    response.success(req, {
        value = req.value,
        type = req.type,
    })
end

function CMD.loadedSource(w, req)
    if req.source and req.source.sourceReference then
        req.source.sourceReference = (w << 32) | req.source.sourceReference
    end
    event.loadedSource(req.reason, req.source)
end

return CMD
