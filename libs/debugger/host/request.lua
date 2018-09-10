local m = {}

local seq = 0
local function newSeq()
    seq = seq + 1
    return seq
end

function m.initialize()
    m.send {
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
    m.send {
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
    m.send {
        type = 'request',
        command = 'configurationDone',
        seq = newSeq(),
    }
end

function m.stackTrace(threadId, startFrame, levels)
    m.send {
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
    m.send {
        type = 'request',
        command = 'threads',
        seq = newSeq(),
    }
end

function m.next(threadId)
    m.send {
        type = 'request',
        command = 'next',
        seq = newSeq(),
        arguments = {
            threadId = threadId,
        },
    }
end

function m.stepIn(threadId)
    m.send {
        type = 'request',
        command = 'stepIn',
        seq = newSeq(),
        arguments = {
            threadId = threadId,
        },
    }
end

function m.stepOut(threadId)
    m.send {
        type = 'request',
        command = 'stepOut',
        seq = newSeq(),
        arguments = {
            threadId = threadId,
        },
    }
end

function m.continue(threadId)
    m.send {
        type = 'request',
        command = 'continue',
        seq = newSeq(),
        arguments = {
            threadId = threadId,
        },
    }
end

function m.pause(threadId)
    m.send {
        type = 'request',
        command = 'pause',
        seq = newSeq(),
        arguments = {
            threadId = threadId,
        },
    }
end

return m
