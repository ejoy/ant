local event = require 'new-debugger.event'
local response = require 'new-debugger.response'
local path = require 'new-debugger.path'

local CMD = {}

function CMD.eventStop(w, req)
    event.stopped(w, req.reason)
end

local function sourceCreate(source)
    local h = source:sub(1, 1)
    if h == '@' or h == '=' then
        return {
             -- TODO path_convert
            path = source:sub(2)
        }
    else
        return {
            ref = source
        }
    end
end

local function sourceOutput(s)
    if s.ref then
        return {
            name = '<Memory>',
            -- TODO:
            sourceReference = 100,
        }
    else
        return {
            name = path.filename(s.path),
            path = path.normalize(s.path),
        }
    end
end

function CMD.stackTrace(w, req)
    for _, frame in ipairs(req.stackFrames) do
        frame.id = (w << 16) | frame.id
        if frame.source then
            frame.source = sourceOutput(sourceCreate(frame.source))
        end
    end
    response.success(req, {
        stackFrames = req.stackFrames,
        totalFrames = req.totalFrames,
    })
end

function CMD.scopes(w, req)
    for _, scope in ipairs(req.scopes) do
        scope.variablesReference = (w << 32) | scope.variablesReference
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
            var.variablesReference = (w << 32) | var.variablesReference
        end
    end
    response.success(req, {
        variables = req.variables
    })
end

return CMD
