local rdebug = require 'remotedebug.visitor'
local fs = require 'backend.worker.filesystem'
local source = require 'backend.worker.source'
local evaluate = require 'backend.worker.evaluate'
local ev = require 'common.event'
local hookmgr = require 'remotedebug.hookmgr'

local breakpoints = {}
local waitverify = {}
local info = {}
local m = {}
local enable = false

local function nextActiveLine(si, line)
    local defines = si.definelines
    if line > #defines then
        return
    end
    local actives = si.activelines
    local fn = defines[line]
    while actives[line] ~= true do
        if fn ~= defines[line] then
            return
        end
        line = line + 1
    end
    return line
end

local function updateHook()
    if enable then
        if next(breakpoints) == nil and next(waitverify) == nil then
            enable = false
            hookmgr.break_close()
        end
    else
        if next(breakpoints) ~= nil or next(waitverify) ~= nil then
            enable = true
            hookmgr.break_open()
        end
    end
end

local function hasActiveBreakpoint(bps, activeline)
    for line in pairs(bps) do
        if activeline[line] then
            return true
        end
    end
    return false
end

local function updateBreakpoint(key, src, bps)
    if next(bps) == nil then
        breakpoints[key] = nil
        for proto in pairs(src.protos) do
            hookmgr.break_del(proto)
        end
    else
        breakpoints[key] = bps
        for proto, activeline in pairs(src.protos) do
            if hasActiveBreakpoint(bps, activeline) then
                activeline.bp = true
                hookmgr.break_add(proto)
            else
                activeline.bp = false
                hookmgr.break_del(proto)
            end
        end
    end
    updateHook()
end

local function bpKey(src)
    if src.sourceReference then
        return src.sourceReference
    end
    return fs.path_native(fs.path_normalize(src.path))
end

local function valid(bp)
    if bp.condition then
        if not evaluate.verify(bp.condition) then
            return false
        end
    end
    if bp.hitCondition then
        if not evaluate.verify('0 ' .. bp.hitCondition) then
            return false
        end
    end
    return true
end

local function verifyBreakpoint(src, clientsrc, bps)
    if not clientsrc.si then
        return
    end
    local key = bpKey(src)
    local oldBP = breakpoints[key]
    local hits = {}
    if oldBP then
        for _, bp in ipairs(oldBP) do
            hits[bp.realLine] = bp.statHit
        end
    end

    local res = {}
    for _, bp in ipairs(bps) do
        if not valid(bp) then
            goto continue
        end
        local activeline = nextActiveLine(clientsrc.si, bp.line)
        if not activeline then
            goto continue
        end
        bp.source = src
        bp.realLine = bp.line
        bp.line = activeline
        res[bp.line] = bp
        bp.statHit = hits[bp.realLine] or 0
        if bp.logMessage then
            local n = 0
            bp.statLog = {}
            bp.statLog[1] = bp.logMessage:gsub('%b{}', function(str)
                n = n + 1
                local key = ('{%d}'):format(n)
                bp.statLog[key] = str:sub(2,-2)
                return key
            end)
            bp.statLog[1] = bp.statLog[1] .. '\n'
        end
        ev.emit('breakpoint', 'changed', {
            id = bp.id,
            line = bp.line,
            message = bp.message,
            verified = true,
        })
        ::continue::
    end
    updateBreakpoint(key, src, res)
end

function m.find(src, currentline)
    local currentBP = breakpoints[bpKey(src)]
    if not currentBP then
        hookmgr.break_closeline()
        return
    end
    return currentBP[currentline]
end

function m.set_bp(clientsrc, breakpoints, content)
    local src = source.c2s(clientsrc, content)
    if src then
        clientsrc.si = clientsrc.si or src.si
        verifyBreakpoint(src, clientsrc, breakpoints)
        return
    end
    waitverify[bpKey(clientsrc)] = { clientsrc, breakpoints }
    updateHook()
end

function m.exec(bp)
    if bp.condition then
        local ok, res = evaluate.eval(bp.condition)
        if not ok or not res then
            return false
        end
    end
    bp.statHit = bp.statHit + 1
    if bp.hitCondition then
        local ok, res = evaluate.eval(bp.statHit .. ' ' .. bp.hitCondition)
        if not ok or res ~= true then
            return false
        end
    end
    if bp.statLog then
        local res = bp.statLog[1]:gsub('{%d+}', function(key)
            local info = bp.statLog[key]
            if not info then
                return key
            end
            local ok, res = evaluate.eval(info)
            if not ok then
                return '{'..info..'}'
            end
            return tostring(res)
        end)
        rdebug.getinfo(1, "Sl", info)
        local src = source.create(info.source)
        if source.valid(src) then
            ev.emit('output', 'stdout', res, src, info.currentline)
        else
            ev.emit('output', 'stdout', res)
        end
        return false
    end
    return true
end

local function sourceUpdateBreakpoint(src)
    local key = bpKey(src)
    local wv = waitverify[key]
    if wv then
        waitverify[key] = nil
        verifyBreakpoint(src, wv[1], wv[2])
        return
    end
    local bps = breakpoints[key]
    if bps then
        updateBreakpoint(key, src, bps)
        return
    end
end

function m.newproto(proto, src, activeline)
    src.protos[proto] = activeline
    sourceUpdateBreakpoint(src)
    return activeline.bp
end

local funcs = {}
function m.set_funcbp(breakpoints)
    funcs = {}
    for _, bp in ipairs(breakpoints) do
        if evaluate.verify(bp.name) then
            funcs[#funcs+1] = bp.name
        end
    end
    hookmgr.funcbp_open(#funcs > 0)
end

function m.hit_funcbp(func)
    for _, funcstr in ipairs(funcs) do
        local ok, res = evaluate.eval(funcstr, 1)
        if ok and res == func then
            return true
        end
    end
end

ev.on('terminated', function()
    breakpoints = {}
    waitverify = {}
    info = {}
    m = {}
    enable = false
    hookmgr.break_close()
end)

return m
