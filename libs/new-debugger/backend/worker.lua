local rdebug = require 'remotedebug'
local cdebug = require 'debugger.backend'
local json = require 'cjson'
local variables = require 'new-debugger.backend.worker.variables'
local source = require 'new-debugger.backend.worker.source'
local breakpoint = require 'new-debugger.backend.worker.breakpoint'
local evaluate = require 'new-debugger.backend.worker.evaluate'
local hookmgr = require 'new-debugger.backend.worker.hookmgr'
local traceback = require 'new-debugger.backend.worker.traceback'
local ev = require 'new-debugger.event'

local initialized = false
local info = {}
local state = 'running'
local stopReason = 'unknown'
local stepLevel = -1
local stepContext = ''
local stepCurrentLevel = -1
local exceptionFilters = {}
local exceptionMsg = ''
local exceptionTrace = ''

local CMD = {}

local masterThread = cdebug.start 'worker'

local function masterThreadUpdate()
    while true do
        local msg = masterThread:recv()
        if not msg then
            break
        end
        local pkg = assert(json.decode(msg))
        if CMD[pkg.cmd] then
            CMD[pkg.cmd](pkg)
        end
    end
end

local function sendToMaster(msg)
    masterThread:send(assert(json.encode(msg)))
end

ev.on('breakpoint', function(reason, bp)
    sendToMaster {
        cmd = 'eventBreakpoint',
        reason = reason,
        breakpoint = bp,
    }
end)

ev.on('output', function(category, output, source, line)
    sendToMaster {
        cmd = 'eventOutput',
        category = category,
        output = output,
        source = source and {
            name = source.name,
            path = source.path,
            sourceReference = source.sourceReference,
        } or nil,
        line = line,
    }
end)

function CMD.initialized(pkg)
    ev.emit('initialized', pkg.config)
    initialized = true
end

function CMD.terminated()
    initialized = false
    state = 'running'
    ev.emit('terminated')
end

function CMD.stackTrace(pkg)
    local startFrame = pkg.startFrame
    local endFrame = pkg.endFrame
    local curFrame = 0
    local depth = 0
    local info = {}
    local res = {}

    while rdebug.getinfo(depth, info) do
        if curFrame ~= 0 and ((curFrame < startFrame) or (curFrame >= endFrame)) then
            depth = depth + 1
            curFrame = curFrame + 1
            goto continue
        end
        local src
        if curFrame == 0 then
            if info.what == 'C' then
                depth = depth + 1
                goto continue
            else
                src = source.create(info.source)
                if not source.valid(src) then
                    depth = depth + 1
                    goto continue
                end
            end
        end
        if (curFrame < startFrame) or (curFrame >= endFrame) then
            depth = depth + 1
            curFrame = curFrame + 1
            goto continue
        end
        curFrame = curFrame + 1
        if info.what == 'C' then
            res[#res + 1] = {
                id = depth,
                name = info.what == 'main' and "[main chunk]" or info.name,
                line = 0,
                column = 0,
                presentationHint = 'label',
            }
        else
            local src = source.create(info.source)
            if source.valid(src) then
                res[#res + 1] = {
                    id = depth,
                    name = info.what == 'main' and "[main chunk]" or info.name,
                    line = info.currentline,
                    column = 1,
                    source = source.output(src),
                }
            elseif curFrame ~= 0 then
                res[#res + 1] = {
                    id = depth,
                    name = info.what == 'main' and "[main chunk]" or info.name,
                    line = info.currentline,
                    column = 1,
                    presentationHint = 'label',
                }
            end
        end
        depth = depth + 1
        ::continue::
    end
    sendToMaster {
        cmd = 'stackTrace',
        command = pkg.command,
        seq = pkg.seq,
        stackFrames = res,
        totalFrames = curFrame
    }
end

function CMD.source(pkg)
    sendToMaster {
        cmd = 'source',
        command = pkg.command,
        seq = pkg.seq,
        content = source.getCode(pkg.sourceReference),
    }
end

function CMD.scopes(pkg)
    sendToMaster {
        cmd = 'scopes',
        command = pkg.command,
        seq = pkg.seq,
        scopes = variables.scopes(pkg.frameId),
    }
end

function CMD.variables(pkg)
    local vars, err = variables.extand(pkg.frameId, pkg.valueId)
    if not vars then
        sendToMaster {
            cmd = 'variables',
            command = pkg.command,
            seq = pkg.seq,
            success = false,
            message = err,
        }
        return
    end
    sendToMaster {
        cmd = 'variables',
        command = pkg.command,
        seq = pkg.seq,
        success = true,
        variables = vars,
    }
end

function CMD.setVariable(pkg)
    local var, err = variables.set(pkg.frameId, pkg.valueId, pkg.name, pkg.value)
    if not var then
        sendToMaster {
            cmd = 'setVariable',
            command = pkg.command,
            seq = pkg.seq,
            success = false,
            message = err,
        }
        return
    end
    sendToMaster {
        cmd = 'setVariable',
        command = pkg.command,
        seq = pkg.seq,
        success = true,
        value = var.value,
        type = var.type,
    }
end

function CMD.evaluate(pkg)
    local ok, result, ref = evaluate.run(pkg.frameId, pkg.expression, pkg.context)
    if not ok then
        sendToMaster {
            cmd = 'evaluate',
            command = pkg.command,
            seq = pkg.seq,
            success = false,
            message = result,
        }
        return
    end
    sendToMaster {
        cmd = 'evaluate',
        command = pkg.command,
        seq = pkg.seq,
        success = true,
        result = result,
        variablesReference = ref,
    }
end

function CMD.setBreakpoints(pkg)
    if not source.valid(pkg.source) then
        return
    end
    breakpoint.update(pkg.source, pkg.source.si, pkg.breakpoints)
end

function CMD.setExceptionBreakpoints(pkg)
    exceptionFilters = {}
    for _, filter in ipairs(pkg.filters) do
        exceptionFilters[filter] = true
    end
end

function CMD.exceptionInfo(pkg)
    sendToMaster {
        cmd = 'exceptionInfo',
        command = pkg.command,
        seq = pkg.seq,
        breakMode = 'always',
        exceptionId = exceptionMsg,
        details = {
            stackTrace = exceptionTrace,
        }
    }
end

function CMD.stop(pkg)
    state = 'stopped'
    stopReason = pkg.reason
    hookmgr.openStepIn()
end

function CMD.run()
    state = 'running'
    hookmgr.closeStep()
    hookmgr.closeStepIn()
end

function CMD.stepOver()
    state = 'stepOver'
    stepContext = rdebug.context()
    stepLevel = rdebug.stacklevel()
    stepCurrentLevel = stepLevel
    hookmgr.openStep()
end

function CMD.stepIn()
    state = 'stepIn'
    stepContext = ''
    hookmgr.openStepIn()
end

function CMD.stepOut()
    state = 'stepOut'
    stepContext = rdebug.context()
    stepCurrentLevel = rdebug.stacklevel()
    stepLevel = stepCurrentLevel - 1
    hookmgr.openStep()
end

local function runLoop(reason)
    sendToMaster {
        cmd = 'eventStop',
        reason = reason,
    }

    while true do
        cdebug.sleep(10)
        masterThreadUpdate()
        if state ~= 'stopped' then
            break
        end
    end
    variables.clean()
    evaluate.clean()
end

local hook = {}

hook['call'] = function()
    local currentContext = rdebug.context()
    if currentContext == stepContext then
        stepCurrentLevel = stepCurrentLevel + 1
    end
    breakpoint.reset()
end

hook['return'] = function ()
    local currentContext = rdebug.context()
    if currentContext == stepContext then
        stepCurrentLevel = rdebug.stacklevel() - 1
    end
    breakpoint.reset()
end

hook['tail call'] = function ()
    breakpoint.reset()
end

hook['line'] = function(line)
    local s = rdebug.getinfo(1, info)
    local src = source.create(s.source)
    if not source.valid(src) then
        hookmgr.closeLineBP()
        return
    end

    local bp = breakpoint.find(src, line)
    if bp then
        if breakpoint.exec(bp) then
            state = 'stopped'
            runLoop('breakpoint')
            return
        end
    end

    masterThreadUpdate()
    if state == 'running' then
        return
    elseif state == 'stepOver' or state == 'stepOut' then
        local currentContext = rdebug.context()
        if currentContext ~= stepContext or stepCurrentLevel > stepLevel then
            return
        end
        state = 'stopped'
    elseif state == 'stepIn' then
        state = 'stopped'
    end
    if state == 'stopped' then
        runLoop(stopReason)
    end
end

hook['update'] = function()
    masterThreadUpdate()
end

local function getEventLevel()
    local level = 0
    local name, value = rdebug.getlocal(1, 2)
    if name ~= nil then
        local type, subtype = rdebug.type(value)
        if subtype == 'integer' then
            level = rdebug.value(value)
        end
    end
    return level + 1
end

local function getEventArgs(i)
    local name, value = rdebug.getlocal(1, -i)
    if name == nil then
        return false
    end
    return true, rdebug.value(value)
end

local function setEventRet(v)
    local name, value = rdebug.getlocal(1, 3)
    if name ~= nil then
        return rdebug.assign(value, v)
    end
    return false
end

local function pairsEventArgs()
    return function(_, i)
        local ok, value = getEventArgs(i)
        if ok then
            return i + 1, value
        end
    end, nil, 1
end

hook['print'] = function()
    if not initialized then return end
    local res = {}
    for _, arg in pairsEventArgs() do
        res[#res + 1] = tostring(rdebug.value(arg))
    end
    res = table.concat(res, '\t')
    local s = rdebug.getinfo(1 + getEventLevel(), info)
    local src = source.create(s.source)
    if source.valid(src) then
        ev.emit('output', 'stdout', res, src, s.currentline)
    else
        ev.emit('output', 'stdout', res)
    end
    setEventRet(true)
end

hook['exception'] = function()
    if not initialized then return end
    local _, type = getEventArgs(1)
    if not type or not exceptionFilters[type] then
        return
    end
    local _, msg = getEventArgs(2)
    local level = getEventLevel()
    exceptionMsg, exceptionTrace = traceback(msg, level)
    state = 'stopped'
    runLoop('exception')
end

rdebug.sethook(function(event, line)
    assert(xpcall(function()
        if hook[event] then
            hook[event](line)
        end
    end, debug.traceback))
end)

sendToMaster {
    cmd = 'ready',
}
