local rdebugM = require 'remotedebug'
local rdebug = require 'remotedebug.visitor'
local json = require 'cjson.safe' json.encode_empty_table_as_array 'on'
local variables = require 'debugger.backend.worker.variables'
local source = require 'debugger.backend.worker.source'
local breakpoint = require 'debugger.backend.worker.breakpoint'
local evaluate = require 'debugger.backend.worker.evaluate'
local traceback = require 'debugger.backend.worker.traceback'
local ev = require 'debugger.event'
local hookmgr = require 'remotedebug.hookmgr'
local thread = require 'thread'
local err = thread.channel_produce 'errlog'

local initialized = false
local info = {}
local state = 'running'
local stopReason = 'step'
local exceptionFilters = {}
local exceptionMsg = ''
local exceptionTrace = ''

local CMD = {}

thread.newchannel ('DbgWorker' .. thread.id)
local masterThread = thread.channel_produce 'DbgMaster'
local workerThread = thread.channel_consume ('DbgWorker' .. thread.id)

local function workerThreadUpdate()
    while true do
        local ok, msg = workerThread:pop()
        if not ok then
            break
        end
        local pkg = assert(json.decode(msg))
        if CMD[pkg.cmd] then
            CMD[pkg.cmd](pkg)
        end
    end
end

local function sendToMaster(msg)
	masterThread:push(thread.id, assert(json.encode(msg)))
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

ev.on('loadedSource', function(reason, source)
    sendToMaster {
        cmd = 'loadedSource',
        reason = reason,
        source = source
    }
end)

--function print(...)
--    local n = select('#', ...)
--    local t = {}
--    for i = 1, n do
--        t[i] = tostring(select(i, ...))
--    end
--    ev.emit('output', 'stdout', table.concat(t, '\t')..'\n')
--end

function CMD.initializing(pkg)
    ev.emit('initializing', pkg.config)
end

function CMD.initialized()
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
                name = info.what == 'main' and '[main chunk]' or info.name,
                line = 0,
                column = 0,
                presentationHint = 'label',
            }
        else
            local src = source.create(info.source)
            if source.valid(src) then
                res[#res + 1] = {
                    id = depth,
                    name = info.what == 'main' and '[main chunk]' or info.name,
                    line = info.currentline,
                    column = 1,
                    source = source.output(src),
                }
            elseif curFrame ~= 0 then
                res[#res + 1] = {
                    id = depth,
                    name = info.what == 'main' and '[main chunk]' or info.name,
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

function CMD.loadedSources()
    source.all_loaded()
end

function CMD.stop(pkg)
    state = 'stopped'
    stopReason = pkg.reason
    hookmgr.step_in()
end

function CMD.run()
    state = 'running'
    hookmgr.step_cancel()
end

function CMD.stepOver()
    state = 'stepOver'
    hookmgr.step_over()
end

function CMD.stepIn()
    state = 'stepIn'
    hookmgr.step_in()
end

function CMD.stepOut()
    state = 'stepOut'
    hookmgr.step_out()
end

local function runLoop(reason)
    sendToMaster {
        cmd = 'eventStop',
        reason = reason,
    }

    while true do
        thread.sleep(0.01)
        workerThreadUpdate()
        if state ~= 'stopped' then
            break
        end
    end
    variables.clean()
    evaluate.clean()
end

local hook = {}

function hook.bp(line)
    local s = rdebug.getinfo(0, info)
    local src = source.create(s.source)
    if not source.valid(src) then
        hookmgr.break_closeline()
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
end

function hook.step()
    local s = rdebug.getinfo(0, info)
    local src = source.create(s.source)
    if not source.valid(src) then
        return
    end
    workerThreadUpdate()
    if state == 'running' then
        return
    elseif state == 'stepOver' or state == 'stepOut' or state == 'stepIn' then
        state = 'stopped'
        stopReason = 'step'
        hookmgr.step_cancel()
    end
    if state == 'stopped' then
        runLoop(stopReason)
    end
end

function hook.newproto(proto, level)
    local s = rdebug.getinfo(level, info)
    local src = source.create(s.source)
    if not source.valid(src) then
        return false
    end
    return breakpoint.newproto(proto, src, hookmgr.activeline(level))
end

local function getEventLevel()
    local level = 0
    local name, value = rdebug.getlocal(1, 2)
    if name ~= nil then
        local _, subtype = rdebug.type(value)
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

local function getEventArgsRaw(i)
    local name, value = rdebug.getlocal(1, -i)
    if name == nil then
        return false
    end
    return true, value
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

local event = {}

function event.update()
    workerThreadUpdate()
end

function event.print()
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

function event.exception()
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

function event.coroutine()
    local _, co = getEventArgsRaw(1)
    hookmgr.setcoroutine(co)
end

local createMaster = true
function event.update_all()
    if createMaster then
        createMaster = false
        local master = require 'debugger.backend.master'
        if master.init() then
            local master = master.update
            local worker = workerThreadUpdate
            function workerThreadUpdate()
                master()
                worker()
            end
        end
    end
    workerThreadUpdate()
end

function event.wait_client()
    local _, all = getEventArgs(1)
    while not initialized do
        thread.sleep(0.01)
        if all then
            event.update_all()
        else
            event.update()
        end
    end
end

rdebugM.sethook(function(name)
    local ok, e = xpcall(function()
        if event[name] then
            event[name]()
        end
    end, debug.traceback)
    if not ok then err.push(e) end
end)

hookmgr.sethook(function(name, ...)
    local ok, e = xpcall(function(...)
        if hook[name] then
            return hook[name](...)
        end
    end, debug.traceback, ...)
    if not ok then err.push(e) end
    return e
end)

ev.on('terminated', function()
    hookmgr.step_cancel()
end)

sendToMaster {
    cmd = 'ready',
}
