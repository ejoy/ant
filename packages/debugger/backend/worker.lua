local rdebug = require 'remotedebug.visitor'
local json = require 'common.json'
local variables = require 'backend.worker.variables'
local source = require 'backend.worker.source'
local breakpoint = require 'backend.worker.breakpoint'
local evaluate = require 'backend.worker.evaluate'
local traceback = require 'backend.worker.traceback'
local stdout = require 'backend.worker.stdout'
local luaver = require 'backend.worker.luaver'
local ev = require 'backend.event'
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
local exceptionLevel = 0
local outputCapture = {}
local noDebug = false
local openUpdate = false
local coroutineTree = {}
local stackFrame = {}
local skipFrame = 0
local baseL

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
        local ok, e = xpcall(function()
            local pkg = json.decode(msg)
            local f = CMD[pkg.cmd]
            if f then
                f(pkg)
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

local function cleanFrame()
    variables.clean()
    stackFrame = {}
end

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
        sendToMaster {
            cmd = 'eventThread',
            reason = 'exited',
        }
    end
end

local function getFuncName(depth)
    if info.what == 'main' then
        return '(main)'
    end
    if info.namewhat == '' then
        if luaver.LUAVERSION >= 52
            and info.what == "Lua"
            and rdebug.getinfo(depth, "t", info)
            and info.istailcall
        then
            return '(...tail calls...)'
        end
        local previous = {}
        if rdebug.getinfo(depth+1, "S", previous) then
            if previous.what == "Lua" or previous.what == "main" then
                return '(anonymous function)'
            end
            if previous.what == "C" then
                return '(called from C)'
            end
        end
        return ('(%s ?)'):format(info.what)
    end
    if info.namewhat == 'for iterator' then
        return '(for iterator)'
    end
    if info.namewhat == 'hook' then
        return '(hook)'
    end
    if info.namewhat == 'metamethod' then
        return ('(metamethod %s)'):format(info.name)
    end
    if info.namewhat == 'field' and info.name == 'integer index' then
        return '(field ?)'
    end
    if info.name == '?' then
        return ('(%s ?)'):format(info.namewhat)
    end
    return info.name
end

local function stackTrace(res, coid, start, levels)
    for depth = start, start + levels - 1 do
        if not rdebug.getinfo(depth, "Sln", info) then
            return depth - start
        end
        local r = {
            id = (coid << 16) | depth,
            name = getFuncName(depth),
            line = 0,
            column = 0,
        }
        if info.what ~= 'C' then
            r.line = info.currentline
            r.column = 1
            local src = source.create(info.source)
            if source.valid(src) then
                r.source = source.output(src)
                r.presentationHint = 'normal'
            else
                r.presentationHint = 'label'
            end
        else
            r.presentationHint = 'label'
        end
        res[#res + 1] = r
    end
    return levels
end

local function calcStackLevel()
    if stackFrame.total then
        return
    end
    local n = 0
    local L = baseL
    repeat
        hookmgr.sethost(L)
        local sl = hookmgr.stacklevel()
        local curL = L
        stackFrame[#stackFrame+1] = curL
        L = coroutineTree[curL]
        if not L then
            for depth = sl-1, 0, -1 do
                if not rdebug.getinfo(depth, "S", info) or info.what ~= "C" then
                    break
                end
                sl = sl - 1
            end
            if skipFrame > 0 then
                skipFrame = math.min(sl, skipFrame)
                sl = sl - skipFrame
            end
        end
        n = n + sl
        stackFrame[curL] = sl
    until not L
    hookmgr.sethost(baseL)
    stackFrame.total = n
end

function CMD.stackTrace(pkg)
    local start = pkg.startFrame and pkg.startFrame or 0
    local levels = (pkg.levels and pkg.levels ~= 0) and pkg.levels or 200
    local res = {}

    --
    -- 在VSCode的实现中这是一帧的第一个请求，所以在这里清理上一帧的数据。
    -- 很特殊，但目前也只能这样。
    --
    if start == 0 and levels == 1 then
        cleanFrame()
    end

    calcStackLevel()

    if start + levels > stackFrame.total then
        levels = stackFrame.total - start
    end

    local L = baseL
    local coroutineId = 0
    repeat
        hookmgr.sethost(L)
        local curL = L
        L = coroutineTree[curL]
        if start > stackFrame[curL] then
            start = start - stackFrame[curL]
        else
            if not L then
                start = start + skipFrame
            end
            local n = stackTrace(res, coroutineId, start, levels)
            if levels == n then
                break
            end
            start = 0
            levels = levels - n
        end
        coroutineId = coroutineId + 1
    until (not L or levels <= 0)
    hookmgr.sethost(baseL)

    sendToMaster {
        cmd = 'stackTrace',
        command = pkg.command,
        seq = pkg.seq,
        success = true,
        stackFrames = res,
        totalFrames = stackFrame.total,
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
    local coid = (pkg.frameId >> 16) + 1
    local depth = pkg.frameId & 0xFFFF
    hookmgr.sethost(assert(stackFrame[coid]))
    sendToMaster {
        cmd = 'scopes',
        command = pkg.command,
        seq = pkg.seq,
        scopes = variables.scopes(depth),
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
    local depth = pkg.frameId & 0xFFFF
    local ok, result = evaluate.run(depth, pkg.expression, pkg.context)
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
    cleanFrame()
    sendToMaster {
        cmd = 'eventStop',
        reason = 'restart',
    }
end

local function runLoop(reason, text, level)
    baseL = hookmgr.gethost()
    --TODO: 只在lua栈帧时需要text？
    sendToMaster {
        cmd = 'eventStop',
        reason = reason,
        text = text,
    }
    skipFrame = level or 0

    while true do
        workerThreadUpdate(0.01)
        if state ~= 'stopped' then
            break
        end
    end
end

local event = {}

local function event_breakpoint(src, line)
    if not source.valid(src) then
        hookmgr.break_closeline()
        return
    end
    local bp = breakpoint.find(src, line)
    if bp then
        if breakpoint.exec(bp) then
            state = 'stopped'
            runLoop 'breakpoint'
            return true
        end
    end
end

function event.bp(line)
    if not initialized then return end
    rdebug.getinfo(0, "S", info)
    local src = source.create(info.source)
    event_breakpoint(src, line)
end

function event.funcbp(func)
    if not initialized then return end
    if breakpoint.hit_funcbp(func) then
        state = 'stopped'
        runLoop 'function breakpoint'
    end
end

function event.step(line)
    if not initialized then return end
    rdebug.getinfo(0, "S", info)
    local src = source.create(info.source)
    if event_breakpoint(src, line) then
        return
    end
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

function event.newproto(proto, level)
    if not initialized then return end
    rdebug.getinfo(level, "S", info)
    local src = source.create(info.source)
    if not source.valid(src) then
        return false
    end
    return breakpoint.newproto(proto, src, info.linedefined.."-"..info.lastlinedefined)
end

local function getEventArgs(i)
    local name, value = rdebug.getlocal(1, -i)
    if name == nil then
        return
    end
    return rdebug.value(value)
end

local function pairsEventArgs()
    local max = rdebug.getstack()
    local n = 1
    return function()
        n = n + 1
        if n > max then
            return
        end
        return n, rdebug.getstack(n)
    end
end

local function getExceptionType()
    local pcall = rdebug.value(rdebug.fieldv(rdebug._G, 'pcall'))
    local xpcall = rdebug.value(rdebug.fieldv(rdebug._G, 'xpcall'))
    local level = 1
    while true do
        local f = rdebug.getfunc(level)
        if f == nil then
            break
        end
        f = rdebug.value(f)
        if f == pcall then
            return 'pcall'
        end
        if f == xpcall then
            return 'xpcall'
        end
        level = level + 1
    end
    return 'lua_pcall'
end

function event.update()
    workerThreadUpdate()
end

function event.print()
    if not initialized then return end
    local res = {}
    for _, arg in pairsEventArgs() do
        res[#res + 1] = variables.tostring(arg)
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
    for _, arg in pairsEventArgs() do
        res[#res + 1] = variables.tostring(arg)
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
    exceptionMsg, exceptionTrace, exceptionLevel = traceback(tostring(msg))
    state = 'stopped'
    runLoop('exception', exceptionMsg, exceptionLevel)
end

function event.r_exception(msg)
    if not initialized then return end
    local type = getExceptionType()
    if not type or not exceptionFilters[type] then
        return
    end
    exceptionMsg, exceptionTrace, exceptionLevel = traceback(tostring(msg))
    state = 'stopped'
    runLoop('exception', exceptionMsg, exceptionLevel)
end

function event.exception()
    if not initialized then return end
    local type = getExceptionType()
    if not type or not exceptionFilters[type] then
        return
    end
    local msg = getEventArgs(2)
    exceptionMsg, exceptionTrace, exceptionLevel = traceback(msg)
    state = 'stopped'
    runLoop('exception', exceptionMsg, exceptionLevel)
end

function event.r_thread(co, type)
    local L = hookmgr.gethost()
    if co then
        if type == 0 then
            coroutineTree[L] = co
        elseif type == 1 then
            coroutineTree[co] = nil
        end
    end
    hookmgr.updatehookmask(L)
end

function event.thread()
    local co = getEventArgs(1)
    local type = getEventArgs(2)
    event.r_thread(co, type)
end

function event.wait()
    while not initialized do
        workerThreadUpdate(0.01)
    end
end

function event.exit()
    CMD.terminated()
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
