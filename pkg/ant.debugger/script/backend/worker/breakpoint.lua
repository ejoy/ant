local rdebug = require 'luadebug.visitor'
local fs = require 'backend.worker.filesystem'
local source = require 'backend.worker.source'
local eval = require 'backend.worker.eval'
local ev = require 'backend.event'
local hookmgr = require 'luadebug.hookmgr'
local parser = require 'backend.worker.parser'
local stdout = require 'backend.worker.stdout'

local currentactive = {}
local waitverify = {}
local info = {}
local m = {}
local enable = false

local function updateHook()
    if enable then
        if next(currentactive) == nil and next(waitverify) == nil then
            enable = false
            hookmgr.break_open(false)
        end
    else
        if next(currentactive) ~= nil or next(waitverify) ~= nil then
            enable = true
            hookmgr.break_open(true)
        end
    end
end

local function hasActiveBreakpoint(bps, activeline)
    if activeline then
        for line in pairs(bps) do
            if activeline[line] then
                return true
            end
        end
    end
    return false
end

local function bpKey(src)
    if src.sourceReference then
        return src.sourceReference
    end
    local path = fs.path_native(fs.path_normalize(src.path))
    if src.startline then
        return path..":"..src.startline
    end
    return path
end

local function bpClientKey(src)
    if src.sourceReference then
        return src.sourceReference
    end
    return fs.path_native(fs.path_normalize(src.path))
end

local function updateBreakpoint(src, breakpoints)
    if not src.lineinfo then
        return
    end
    local bpkey = bpKey(src)
    local bps
    if breakpoints == nil then
        bps = currentactive[bpkey]
        if not bps then
            return
        end
    else
        bps = {}
        for _, bp in ipairs(breakpoints) do
            if bp.verified == true then
                bps[bp.line] = bp
            end
        end
    end
    if next(bps) == nil then
        currentactive[bpkey] = nil
        for proto in pairs(src.protos) do
            hookmgr.break_del(proto)
        end
    else
        currentactive[bpkey] = bps
        local lineinfo = src.lineinfo
        for proto, key in pairs(src.protos) do
            if hasActiveBreakpoint(bps, lineinfo[key]) then
                hookmgr.break_add(proto)
            else
                hookmgr.break_del(proto)
            end
        end
    end
    updateHook()
end

local function NormalizeErrorMessage(what, err)
    return ("%s: %s."):format(what, err:gsub("^:%d+: %(EVAL%):%d+: (.*)$", "%1"))
end

local function setBreakPointUnverified(bp, errmsg)
    bp.unverified = true
    ev.emit('breakpoint', 'changed', {
        id = bp.id,
        message = errmsg,
        verified = false,
    })
end

local function valid(bp)
    if bp.condition then
        local ok, err = eval.verify(bp.condition)
        if not ok then
            setBreakPointUnverified(bp, NormalizeErrorMessage("Condition Error", err))
            return false
        end
    end
    if bp.hitCondition then
        local ok, err = eval.verify('0 '..bp.hitCondition)
        if not ok then
            setBreakPointUnverified(bp, NormalizeErrorMessage("HitCondition Error", err))
            return false
        end
    end
    return true
end

local function verifyBreakpoint(breakpoints)
    local hits = {}
    for _, bp in ipairs(breakpoints) do
        if not valid(bp) then
            goto continue
        end
        bp.realLine = bp.line
        bp.statHit = hits[bp.realLine] or 0
        if bp.logMessage then
            local n = 0
            bp.statLog = {}
            bp.statLog[1] = bp.logMessage:gsub('%b{}', function(str)
                n = n + 1
                local key = ('{%d}'):format(n)
                bp.statLog[key] = str:sub(2, -2)
                return key
            end)
            bp.statLog[1] = bp.statLog[1]..'\n'
        end
        ::continue::
    end
end

local function verifyBreakpointByLineInfo(src, breakpoints)
    local lineinfo = src.lineinfo
    if not lineinfo then
        return
    end
    for _, bp in ipairs(breakpoints) do
        if bp.unverified ~= nil then
            goto continue
        end
        local activeline = lineinfo[bp.line]
        if not activeline then
            if not src.startline then
                setBreakPointUnverified(bp, "The breakpoint didn't hit a valid line.")
            end
            goto continue
        end
        bp.source = src
        bp.line = activeline
        bp.verified = true
        ev.emit('breakpoint', 'changed', {
            id = bp.id,
            line = bp.line,
            verified = true,
        })
        ::continue::
    end
end

function m.find(src, currentline)
    local currentBP = currentactive[bpKey(src)]
    if not currentBP then
        hookmgr.break_closeline()
        return
    end
    return currentBP[currentline]
end

local function parserInlineLineinfo(src)
    local old = parser(src.content)
    if not old then
        return
    end
    local new = {}
    local diff = src.startline - 1
    for k, v in pairs(old) do
        if type(k) == "number" then
            new[k + diff] = v + diff
        else
            local newv = {}
            for l in pairs(v) do newv[l + diff] = true end
            if k == "0-0" then
                new[k] = newv
            else
                local s, e = k:match "^(%d+)-(%d+)$"
                s = tonumber(s) + 1
                e = tonumber(e) + 1
                new[("%d-%d"):format(s, e)] = newv
            end
        end
    end
    return new
end

local function calcLineInfo(src, content)
    if not src.lineinfo then
        if src.content then
            src.lineinfo = parserInlineLineinfo(src)
        elseif content then
            src.lineinfo = parser(content)
        elseif src.sourceReference then
            src.lineinfo = parser(source.getCode(src.sourceReference))
        end
    end
    return src.lineinfo
end

local function cantVerifyBreakpoints(breakpoints)
    for _, bp in ipairs(breakpoints) do
        setBreakPointUnverified(bp, "The source file has no line information.")
    end
end

function m.set_bp(clientsrc, breakpoints, content)
    verifyBreakpoint(breakpoints)

    local srcarray = source.c2s(clientsrc)
    if srcarray then
        local ok = false
        for _, src in ipairs(srcarray) do
            if calcLineInfo(src, content) then
                ok = true
            end
        end
        if ok then
            for _, src in ipairs(srcarray) do
                verifyBreakpointByLineInfo(src, breakpoints)
                updateBreakpoint(src, breakpoints)
            end
        else
            cantVerifyBreakpoints(breakpoints)
        end
    else
        waitverify[bpClientKey(clientsrc)] = {
            breakpoints = breakpoints,
            content = content,
        }
        updateHook()
    end
end

function m.exec(bp)
    if bp.condition then
        local ok, res = eval.eval(bp.condition)
        if not ok or not res then
            return false
        end
    end
    bp.statHit = bp.statHit + 1
    if bp.hitCondition then
        local ok, res = eval.eval(bp.statHit..' '..bp.hitCondition)
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
            local ok, res = eval.eval(info)
            if not ok then
                return '{'..info..'}'
            end
            return tostring(res)
        end)
        rdebug.getinfo(1, "Sl", info)
        stdout(res, info)
        return false
    end
    return true
end

function m.newproto(proto, src, key)
    src.protos[proto] = key
    local bpkey = bpClientKey(src)
    local wv = waitverify[bpkey]
    if wv then
        if not src.content then
            waitverify[bpkey] = nil
        end
        if not calcLineInfo(src, wv.content) then
            cantVerifyBreakpoints(wv.breakpoints)
            return
        end
        verifyBreakpointByLineInfo(src, wv.breakpoints)
        updateBreakpoint(src, wv.breakpoints)
        return
    end
    updateBreakpoint(src)
end

local funcs = {}
function m.set_funcbp(breakpoints)
    funcs = {}
    for _, bp in ipairs(breakpoints) do
        local ok, err = eval.verify(bp.name)
        if not ok then
            setBreakPointUnverified(bp, NormalizeErrorMessage("Error", err))
            goto continue
        end
        if not valid(bp) then
            goto continue
        end
        funcs[#funcs + 1] = bp
        bp.verified = true
        bp.statHit = 0
        ev.emit('breakpoint', 'changed', bp)
        ::continue::
    end
    hookmgr.funcbp_open(#funcs > 0)
end

function m.hit_bp(src, currentline)
    local bp = m.find(src, currentline)
    if bp and m.exec(bp) then
        return bp
    end
end

function m.hit_funcbp(func)
    for _, bp in ipairs(funcs) do
        local ok, res = eval.eval(bp.name, 1)
        if ok and res == func and m.exec(bp) then
            return bp
        end
    end
end

local exceptionFilters = {}

function m.hitExceptionBreakpoint(flags, level, error)
    for _, flag in ipairs(flags) do
        local bp = exceptionFilters[flag]
        if bp then
            if not bp.condition then
                return bp
            end
            local ok, res = eval.eval(bp.condition, level, { error = error })
            if ok and res then
                return bp
            end
        end
    end
end

function m.setExceptionBreakpoints(breakpoints)
    exceptionFilters = {}
    for _, filter in ipairs(breakpoints) do
        if not filter.condition then
            exceptionFilters[filter.filterId] = {
                id = filter.id,
            }
            ev.emit('breakpoint', 'changed', {
                id = filter.id,
                verified = true,
            })
            goto continue
        end
        local ok, err = eval.verify(filter.condition)
        if not ok then
            setBreakPointUnverified(filter, NormalizeErrorMessage("Error", err))
            goto continue
        end
        exceptionFilters[filter.filterId] = {
            id = filter.id,
            condition = filter.condition,
        }
        ev.emit('breakpoint', 'changed', {
            id = filter.id,
            verified = true,
        })
        ::continue::
    end
    if hookmgr.exception_open then
        hookmgr.exception_open(next(exceptionFilters) ~= nil)
    end
end

ev.on('terminated', function()
    currentactive = {}
    waitverify = {}
    info = {}
    enable = false
    hookmgr.break_open(false)
end)

return m
