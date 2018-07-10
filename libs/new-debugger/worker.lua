local rdebug = require 'remotedebug'
local cdebug = require 'debugger.core'
local json = require 'cjson'
local variables = require 'new-debugger.worker.variables'
local source = require 'new-debugger.worker.source'
local breakpoint = require 'new-debugger.worker.breakpoint'
local evaluate = require 'new-debugger.worker.evaluate'
local hookmgr = require 'new-debugger.worker.hookmgr'
local ev = require 'new-debugger.event'

local state = 'running'
local stopReason = 'unknown'
local stepLevel = -1
local stepContext = ''
local stepCurrentLevel = -1

local CMD = {}

local masterThread = cdebug.start('worker', function(msg)
    local pkg = assert(json.decode(msg))
    if CMD[pkg.cmd] then
        CMD[pkg.cmd](pkg)
    end
end)

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
        source = source,
        line = line,
    }
end)

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
        if info.what == 'C' and curFrame == 0 then
            depth = depth + 1
            goto continue
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
            else 
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
    local vars, err = variables.variables(pkg.frameId, pkg.valueId)
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

function CMD.evaluate(pkg)
    local f, err = evaluate.complie('return ' .. pkg.expression)
    if not f then
        sendToMaster {
            cmd = 'evaluate',
            command = pkg.command,
            seq = pkg.seq,
            success = false,
            message = err,
        }
        return
    end
    local ok, res = evaluate.execute(pkg.frameId, f)
    if not ok then
        sendToMaster {
            cmd = 'evaluate',
            command = pkg.command,
            seq = pkg.seq,
            success = false,
            message = res,
        }
        return
    end
    if type(res) == 'table' and res.__ref ~= nil then
        local text, _, ref = variables.createRef(pkg.frameId, res.__ref)
        sendToMaster {
            cmd = 'evaluate',
            command = pkg.command,
            seq = pkg.seq,
            success = true,
            result = text,
            variablesReference = ref,
        }
        return
    end
    sendToMaster {
        cmd = 'evaluate',
        command = pkg.command,
        seq = pkg.seq,
        success = true,
        result = tostring(res) or '',
    }
end

function CMD.setBreakpoints(pkg)
    if not source.valid(pkg.source) then
        return
    end
    breakpoint.update(pkg.source, pkg.breakpoints)
end

function CMD.stop(pkg)
    state = 'stopped'
    stopReason = pkg.reason
end

function CMD.run(pkg)
    state = 'running'
    hookmgr.closeStep()
end

function CMD.stepOver(pkg)
    state = 'stepOver'
    stepContext = rdebug.context()
    stepLevel = rdebug.stacklevel()
    stepCurrentLevel = stepLevel
    hookmgr.openStep()
end

function CMD.stepIn(pkg)
    state = 'stepIn'
    stepContext = ''
    hookmgr.openStep()
end

function CMD.stepOut(pkg)
    state = 'stepOut'
    stepContext = rdebug.context()
    stepLevel = rdebug.stacklevel() - 1
    stepCurrentLevel = stepLevel
    hookmgr.openStep()
end

local function runLoop(reason)
    sendToMaster {
        cmd = 'eventStop',
        reason = reason,
    }

    while true do
        cdebug.sleep(10)
        masterThread:update()
        if state ~= 'stopped' then
            return
        end
    end
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
    local bp = breakpoint.find(line)
    if bp then
        if breakpoint.exec(bp) then
            state = 'stopped'
            runLoop('breakpoint')
            return
        end
    end

    masterThread:update()
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

rdebug.sethook(function(event, line)
    assert(xpcall(function()
        if event == 'update' then
            masterThread:update()
            return
        end
        if hook[event] then
            hook[event](line)
        end
        variables.clean()
        evaluate.clean()
    end, debug.traceback))
end)
