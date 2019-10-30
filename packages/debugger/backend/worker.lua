local rdebug = require 'remotedebug.visitor'
local json = require 'common.json'
local variables = require 'backend.worker.variables'
local source = require 'backend.worker.source'
local breakpoint = require 'backend.worker.breakpoint'
local evaluate = require 'backend.worker.evaluate'
local traceback = require 'backend.worker.traceback'
local stdout = require 'backend.worker.stdout'
local emulator = require 'backend.worker.emulator'
local luaver = require 'backend.worker.luaver'
local ev = require 'common.event'
local hookmgr = require 'remotedebug.hookmgr'
local stdio = require 'remotedebug.stdio'
local thread = require 'remotedebug.thread'
local err = thread.channel 'errlog'

local initialized = false
local info = {}
local state = 'running'
local stopReason = 'step'
local exceptionFilters = {}
local exceptionMsg = ''
local exceptionTrace = ''
local outputCapture = {}
local noDebug = false
local openUpdate = false

local CMD = {}

thread.newchannel ('DbgWorker' .. thread.id)
local masterThread = thread.channel 'DbgMaster'
local workerThread = thread.channel ('DbgWorker' .. thread.id)

local function workerThreadUpdate(timeout)
    while true do
        local ok, msg = workerThread:pop(timeout)
        if not ok then
            break
        end
        local pkg = assert(json.decode(msg))
        local ok, e = xpcall(function()
        if CMD[pkg.cmd] then
            CMD[pkg.cmd](pkg)
        end
        end, debug.traceback)
        if not ok then
            err:push(e)
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

ev.on('loadedSource', function(reason, s)
    sendToMaster {
        cmd = 'loadedSource',
        reason = reason,
        source = source.output(s)
    }
end)

--function print(...)
--    local n = select('#', ...)
--    local t = {}
--    for i = 1, n do
--        t[i] = tostring(select(i, ...))
--    end
--    ev.emit('output', 'stderr', table.concat(t, '\t')..'\n')
--end

--local log = require 'common.log'
--print = log.info

function CMD.initializing(pkg)
    luaver.init()
    ev.emit('initializing', pkg.config)
end

function CMD.initialized()
    initialized = true
end

function CMD.terminated()
    if initialized then
        initialized = false
        state = 'running'
        ev.emit('terminated')
    end
end

function CMD.stackTrace(pkg)
    local startFrame = pkg.startFrame
    local endFrame = pkg.endFrame
    local curFrame = 0
    local virtualFrame = 0
    local depth = 0
    local res = {}

    if startFrame == 0 then
        res = emulator.stackTrace()
        virtualFrame = #res
    end

    while rdebug.getinfo(depth, "Sln", info) do
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
        totalFrames = curFrame + virtualFrame,
    }
end

function CMD.source(pkg)
    sendToMaster {
        cmd = 'source',
        command = pkg.command,
        seq = pkg.seq,
        content = emulator.getCode(pkg.sourceReference),
    }
end

function CMD.scopes(pkg)
    sendToMaster {
        cmd = 'scopes',
        command = pkg.command,
        seq = pkg.seq,
        scopes = emulator.scopes(pkg.frameId),
    }
end

function CMD.variables(pkg)
    local vars, err = variables.extand(pkg.valueId, pkg.filter, pkg.start, pkg.count)
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
    local var, err = variables.set(pkg.valueId, pkg.name, pkg.value)
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
    local ok, result = evaluate.run(pkg.frameId, pkg.expression, pkg.context)
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
    result.result = result.value
    result.value = nil
    sendToMaster {
        cmd = 'evaluate',
        command = pkg.command,
        seq = pkg.seq,
        success = true,
        body = result
    }
end

function CMD.setBreakpoints(pkg)
    if noDebug or not source.valid(pkg.source) then
        return
    end
    breakpoint.set_bp(pkg.source, pkg.breakpoints, pkg.content)
end

function CMD.setFunctionBreakpoints(pkg)
    breakpoint.set_funcbp(pkg.breakpoints)
end

function CMD.setExceptionBreakpoints(pkg)
    exceptionFilters = {}
    for _, filter in ipairs(pkg.filters) do
        exceptionFilters[filter] = true
    end
    if hookmgr.exception_open then
        hookmgr.exception_open(next(exceptionFilters) ~= nil)
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
    if noDebug then
        return
    end
    state = 'stopped'
    stopReason = pkg.reason -- entry or pause
    hookmgr.step_in()
end

function CMD.run()
    state = 'running'
    hookmgr.step_cancel()
end

function CMD.stepOver()
    if noDebug then
        return
    end
    state = 'stepOver'
    hookmgr.step_over()
end

function CMD.stepIn()
    if noDebug then
        return
    end
    state = 'stepIn'
    hookmgr.step_in()
end

function CMD.stepOut()
    if noDebug then
        return
    end
    state = 'stepOut'
    hookmgr.step_out()
end

function CMD.restartFrame()
    variables.clean()
    sendToMaster {
        cmd = 'eventStop',
        reason = 'restart',
    }
end

local function runLoop(reason, text)
    --TODO: 只在lua栈帧时需要text？
    sendToMaster {
        cmd = 'eventStop',
        reason = reason,
        text = text,
    }

    while true do
        workerThreadUpdate(0.01)
        if state ~= 'stopped' then
            break
        end
    end
    variables.clean()
end

local hook = {}

function hook.bp(line)
    if not initialized then return end
    rdebug.getinfo(0, "S", info)
    local src = source.create(info.source)
    if not source.valid(src) then
        hookmgr.break_closeline()
        return
    end
    local bp = breakpoint.find(src, line)
    if bp then
        if breakpoint.exec(bp) then
            state = 'stopped'
            runLoop 'breakpoint'
            return
        end
    end
end

function hook.funcbp(func)
    if not initialized then return end
    if breakpoint.hit_funcbp(func) then
        state = 'stopped'
        runLoop 'function breakpoint'
    end
end

function hook.step()
    if not initialized then return end
    rdebug.getinfo(0, "S", info)
    local src = source.create(info.source)
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
    if not initialized then return end
    rdebug.getinfo(level, "S", info)
    local src = source.create(info.source)
    if not source.valid(src) then
        return false
    end
    return breakpoint.newproto(proto, src, hookmgr.activeline(level))
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

local function pairsEventArgs()
    local n = 2
    return function()
        local value = rdebug.getstack(n)
        if value ~= nil then
            n = n + 1
            return value
        end
    end
end

local function getExceptionType()
    local pcall = rdebug.value(rdebug.index(rdebug._G, 'pcall'))
    local xpcall = rdebug.value(rdebug.index(rdebug._G, 'xpcall'))
    local level = 1
    while true do
        local f = rdebug.getfunc(level)
        if f == nil then
            break
        end
        f = rdebug.value(f)
        if f == pcall then
            return level, 'pcall'
        end
        if f == xpcall then
            return level, 'xpcall'
        end
        level = level + 1
    end
    return nil, 'lua_pcall'
end

local event = hook

function event.update()
    workerThreadUpdate()
end

function event.print()
    if not initialized then return end
    local res = {}
    for arg in pairsEventArgs() do
        res[#res + 1] = rdebug.tostring(arg)
    end
    res = table.concat(res, '\t') .. '\n'
    rdebug.getinfo(1, "Sl", info)
    local src = source.create(info.source)
    if source.valid(src) then
        stdout(res, src, info.currentline)
    else
        stdout(res)
    end
    return true
end

function event.iowrite()
    if not initialized then return end
    local res = {}
    for arg in pairsEventArgs() do
        res[#res + 1] = rdebug.tostring(arg)
    end
    res = table.concat(res, '\t')
    rdebug.getinfo(1, "Sl", info)
    local src = source.create(info.source)
    if source.valid(src) then
        stdout(res, src, info.currentline)
    else
        stdout(res)
    end
    return true
end

function event.panic(msg)
    if not initialized then return end
    if not exceptionFilters['lua_panic'] then
        return
    end
    exceptionMsg, exceptionTrace = traceback(tostring(msg), 0)
    state = 'stopped'
    runLoop('exception', exceptionMsg)
end

function event.r_exception(msg)
    if not initialized then return end
    local _, type = getExceptionType()
    if not type or not exceptionFilters[type] then
        return
    end
    exceptionMsg, exceptionTrace = traceback(tostring(msg), 0)
    state = 'stopped'
    runLoop('exception', exceptionMsg)
end

function event.exception()
    if not initialized then return end
    local level, type = getExceptionType()
    if not type or not exceptionFilters[type] then
        return
    end
    local _, msg = getEventArgs(1)
    exceptionMsg, exceptionTrace = traceback(msg, level - 3)
    state = 'stopped'
    runLoop('exception', exceptionMsg)
end

function event.r_thread(co)
    hookmgr.setcoroutine(co)
end

function event.thread()
    local _, co = getEventArgsRaw(1)
    hookmgr.setcoroutine(co)
end

function event.wait()
    while not initialized do
        workerThreadUpdate(0.01)
    end
end

function event.event_call()
    local code = rdebug.value(rdebug.getstack(2))
    local name = rdebug.value(rdebug.getstack(3))
    if emulator.eventCall(state, code, name) then
        return true
    end
end

function event.event_return()
    emulator.eventReturn()
end

function event.event_line()
    local line = rdebug.value(rdebug.getstack(2))
    local scope = rdebug.getstack(3)
    if emulator.eventLine(state, line, scope) then
        emulator.open()
        state = 'stopped'
        runLoop 'step'
        emulator.close()
    end
end

function event.exit()
    local exit = initialized
    CMD.terminated()
    if exit then
        sendToMaster {
            cmd = 'eventThread',
            reason = 'exited',
        }
    end
end

hookmgr.init(function(name, ...)
    local ok, e = xpcall(function(...)
        if event[name] then
            return event[name](...)
        end
    end, debug.traceback, ...)
    if not ok then
        err:push(e)
        return
    end
    return e
end)

local function lst2map(t)
    local r = {}
    for _, v in ipairs(t) do
        r[v] = true
    end
    return r
end

local function init_internalmodule(config)
    local mod = config.internalModule
    if not mod then
        return
    end
    local newvalue = rdebug.index(rdebug.index(rdebug.index(rdebug._G, "package"), "loaded"), mod)
    local oldvalue = rdebug.index(rdebug._REGISTRY, "lua-debug")
    rdebug.assign(newvalue, oldvalue)
end

ev.on('initializing', function(config)
    noDebug = config.noDebug
    hookmgr.update_open(not noDebug and openUpdate)
    if hookmgr.thread_open then
        hookmgr.thread_open(true)
    end
    outputCapture = lst2map(config.outputCapture)
    if outputCapture["print"] then
        stdio.open_print(true)
    end
    if outputCapture["io.write"] then
        stdio.open_iowrite(true)
    end
    init_internalmodule(config)
end)

ev.on('terminated', function()
    hookmgr.step_cancel()
    if outputCapture["print"] then
        stdio.open_print(false)
    end
    if outputCapture["io.write"] then
        stdio.open_iowrite(false)
    end
end)

sendToMaster {
    cmd = 'eventThread',
    reason = 'started',
}

local w = {}

function w.openupdate()
    openUpdate = true
    hookmgr.update_open(true)
end

return w
