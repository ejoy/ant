local m = {}

local seq = 0
local function newSeq()
    seq = seq + 1
    return seq
end

function m.initialize()
    return m.send {
        type = 'request',
        command = 'initialize',
        seq = newSeq(),
        arguments = {
            clientID = 'ant',
            clientName = 'Ant IDE',
            adapterID = 'lua',
            locale = 'zh-cn',
            linesStartAt1 = true,
            columnsStartAt1 = true,
            pathFormat = 'path',
            supportsVariableType = false,
            supportsVariablePaging = false,
            supportsRunInTerminalRequest = false,
        },
    }
end

function m.attach()
    return m.send {
        type = 'request',
        command = 'attach',
        seq = newSeq(),
        arguments = {
            stopOnEntry = true,
            workspaceFolder = 'D:/work/lab/',
            ip = '127.0.0.1',
            port = 4278,
            sourceMaps = {
            },
            skipFiles = {
            },
        },
    }
end

function m.configurationDone()
    return m.send {
        type = 'request',
        command = 'configurationDone',
        seq = newSeq(),
    }
end

function m.stackTrace(threadId, startFrame, levels)
    return m.send {
        type = 'request',
        command = 'stackTrace',
        seq = newSeq(),
        arguments = {
            threadId = threadId,
            startFrame = startFrame,
            levels = levels,
        },
    }
end

function m.threads()
    return m.send {
        type = 'request',
        command = 'threads',
        seq = newSeq(),
    }
end

function m.next(threadId)
    return m.send {
        type = 'request',
        command = 'next',
        seq = newSeq(),
        arguments = {
            threadId = threadId,
        },
    }
end

function m.stepIn(threadId)
    return m.send {
        type = 'request',
        command = 'stepIn',
        seq = newSeq(),
        arguments = {
            threadId = threadId,
        },
    }
end

function m.stepOut(threadId)
    return m.send {
        type = 'request',
        command = 'stepOut',
        seq = newSeq(),
        arguments = {
            threadId = threadId,
        },
    }
end

function m.continue(threadId)
    return m.send {
        type = 'request',
        command = 'continue',
        seq = newSeq(),
        arguments = {
            threadId = threadId,
        },
    }
end

function m.pause(threadId)
    return m.send {
        type = 'request',
        command = 'pause',
        seq = newSeq(),
        arguments = {
            threadId = threadId,
        },
    }
end

function m.setBreakpoints(source, breakpoints)
    return m.send {
        type = 'request',
        command = 'setBreakpoints',
        seq = newSeq(),
        arguments = {
            source = source,
            breakpoints = breakpoints,
        },
    }
end

function m.source(sourceReference)
    return m.send {
        type = 'request',
        command = 'source',
        seq = newSeq(),
        arguments = {
            sourceReference = sourceReference,
        },
    }
end

return m
