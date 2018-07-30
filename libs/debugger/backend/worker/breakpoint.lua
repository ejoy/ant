local rdebug = require 'remotedebug'
local path = require 'debugger.path'
local source = require 'debugger.backend.worker.source'
local evaluate = require 'debugger.backend.worker.evaluate'
local ev = require 'debugger.event'
local hookmgr = require 'debugger.hookmgr'

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
    if src.path then
        return path.normalize_native(src.path)
    end
    return src.sourceReference
end

local function verifyBreakpoint(src, bps)
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
        local activeline = nextActiveLine(src.si, bp.line)
        if activeline then
            bp.source = src
            bp.realLine = bp.line
            bp.line = activeline
            res[bp.line] = bp

            bp.statHit = hits[bp.realLine] or 0
            if bp.condition then
                local f, err = evaluate.complie('return ' .. bp.condition)
                if not f then
                    bp.message = err
                else
                    bp.statCondition = f
                end
            end
            if bp.hitCondition then
                local f, err = evaluate.complie('return (...)' .. bp.hitCondition)
                if not f then
                    bp.message = err
                else
                    bp.statHitCondition = f
                end
            end
            if bp.logMessage then
                local n = 0
                bp.statLog = {}
                bp.statLog[1] = bp.logMessage:gsub('%b{}', function(str)
                    n = n + 1
                    local key = ('{%d}'):format(n)
                    local f = evaluate.complie('return ' .. str:sub(2,-2))
                    if not f then
                        bp.statLog[key] = { str }
                    else
                        bp.statLog[key] = { str, f }
                    end
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
        end
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

function m.update(clientsrc, si, bps)
    if clientsrc.path then
        if not si then
            return
        end
        local src = source.c2s(clientsrc)
        if src then
            src.si = si
            verifyBreakpoint(src, bps)
            return
        end
        for _, bp in ipairs(bps) do
            bp.source = clientsrc
        end
        waitverify[bpKey(clientsrc)] = { bps, si }
        updateHook()
    else
        local src = source.c2s(clientsrc)
        if src then
            verifyBreakpoint(src, bps)
            return
        end
    end
end

function m.exec(bp)
    if bp.statCondition then
        local ok, res = evaluate.execute(1, bp.statCondition)
        if ok and type(res) == 'boolean' and res == false then
            return false
        end
    end
    bp.statHit = bp.statHit + 1
    if bp.statHitCondition then
        local ok, res = evaluate.execute(1, bp.statHitCondition, bp.statHit)
        if ok and type(res) == 'boolean' and res == false then
            return false
        end
    end
    if bp.statLog then
        local res = bp.statLog[1]:gsub('{%d+}', function(key)
            local info = bp.statLog[key]
            if not info then
                return key
            end
            if not info[2] then
                return info[1]
            end
            local ok, r = evaluate.execute(1, info[2])
            if not ok then
                return info[1]
            end
            return tostring(r)
        end)
        local s = rdebug.getinfo(1, info)
        local src = source.create(s.source)
        if source.valid(src) then
            ev.emit('output', 'stdout', res, src, s.currentline)
        else
            ev.emit('output', 'stdout', res)
        end
        return false
    end
    return true
end

local function sourceUpdateBreakpoint(src)
    local key = bpKey(src)
    local bpssi = waitverify[key]
    if bpssi then
        waitverify[key] = nil
        if src.path then
            src.si = bpssi[2]
        end
        verifyBreakpoint(src, bpssi[1])
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

ev.on('terminated', function()
    breakpoints = {}
    currentBP = nil
    waitverify = {}
    info = {}
    m = {}
    enable = false
    hookmgr.break_close()
end)

return m
