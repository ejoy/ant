local rdebug = require 'remotedebug'
local path = require 'new-debugger.path'
local source = require 'new-debugger.worker.source'
local hookmgr = require 'new-debugger.worker.hookmgr'
local evaluate = require 'new-debugger.worker.evaluate'
local ev = require 'new-debugger.event'

local breakpoints = {}
local currentBP
local waitverify = {}
local info = {}
local m = {}
local enable = false

local function nextActiveLine(src, line)
    if line > src.maxline then
        return
    end
    local defines = src.definelines
    local actives = src.activelines
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
            hookmgr.closeBP()
            enable = false
        end
    else
        if next(breakpoints) ~= nil or next(waitverify) ~= nil then
            hookmgr.openBP()
            enable = true
        end
    end
end

local function verifyBreakpoint(src, bps)
    local normalizePath = path.normalize_native(src.path)
    local oldBP = breakpoints[normalizePath]
    local hits = {}
    if oldBP then
        for _, bp in ipairs(oldBP) do
            hits[bp.realLine] = bp.statHit
        end
    end

    local res = {}
    for _, bp in ipairs(bps) do
        local activeline = nextActiveLine(src, bp.line)
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
    if next(res) == nil then
        breakpoints[normalizePath] = nil
    else
        breakpoints[normalizePath] = res
    end
    updateHook()
    if currentBP and currentBP == oldBP then
        m.reset()
    end
end

function m.reset()
    currentBP = nil
    hookmgr.openLineBP()
end

function m.find(currentline)
    if not currentBP then
        local s = rdebug.getinfo(1, info)
        local src = source.create(s.source)
        if not source.valid(src) then
            hookmgr.closeLineBP()
            return
        end
        if src.path then
            currentBP = breakpoints[path.normalize_native(src.path)]
        else
            currentBP = breakpoints[src.ref]
        end
        if not currentBP then
            hookmgr.closeLineBP()
            return
        end
    end
    return currentBP[currentline]
end

function m.update(clientsrc, bps)
    if not clientsrc.path then
        return
    end
    local src = source.open(clientsrc.path)
    if src then
        verifyBreakpoint(src, bps)
        return
    end
    for _, bp in ipairs(bps) do
        bp.source = clientsrc
    end
    waitverify[path.normalize_native(clientsrc.path)] = bps
    updateHook()
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

ev.on('source-create', function(src)
    if not src.path then
        return
    end
    local nativepath = path.normalize_native(src.path)
    local bps = waitverify[nativepath]
    if not bps then
        return
    end
    waitverify[nativepath] = nil

    verifyBreakpoint(src, bps)
end)

return m
