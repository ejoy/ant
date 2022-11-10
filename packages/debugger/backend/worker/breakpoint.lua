local rdebug = require 'remotedebug.visitor'
local fs = require 'backend.worker.filesystem'
local source = require 'backend.worker.source'
local evaluate = require 'backend.worker.evaluate'
local ev = require 'backend.event'
local hookmgr = require 'remotedebug.hookmgr'
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

local function updateBreakpoint(bpkey, src, bps)
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

local function NormalizeErrorMessage(what, err)
    return ("%s: %s."):format(what, err:gsub("^:%d+: %(EVAL%):%d+: (.*)$", "%1"))
end

local function valid(bp)
    if bp.condition then
        local ok, err = evaluate.verify(bp.condition)
        if not ok then
            ev.emit('breakpoint', 'changed', {
                id = bp.id,
                message = NormalizeErrorMessage("Condition Error", err),
                verified = false,
            })
            return false
        end
    end
    if bp.hitCondition then
        local ok, err = evaluate.verify('0 ' .. bp.hitCondition)
        if not ok then
            ev.emit('breakpoint', 'changed', {
                id = bp.id,
                message = NormalizeErrorMessage("HitCondition Error", err),
                verified = false,
            })
            return false
        end
    end
    return true
end

local function verifyBreakpoint(src, breakpoints)
    local bpkey = bpKey(src)
    local curbp = currentactive[bpkey]
    local lineinfo = src.lineinfo
    local hits = {}
    local res = {}
    if curbp then
        for _, bp in ipairs(curbp) do
            hits[bp.realLine] = bp.statHit
        end
    end
    for _, bp in ipairs(breakpoints) do
        if not valid(bp) then
            goto continue
        end
        local activeline = lineinfo[bp.line]
        if not activeline then
            if not src.startline then
                ev.emit('breakpoint', 'changed', {
                    id = bp.id,
                    message = "The breakpoint didn't hit a valid line.",
                    verified = false,
                })
            end
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
            verified = true,
        })
        ::continue::
    end
    updateBreakpoint(bpkey, src, res)
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
    local new = {}
    local diff = src.startline - 1
    for k, v in pairs(old) do
        if type(k) == "number" then
            new[k+diff] = v+diff
        else
            local newv = {}
            for l in pairs(v) do newv[l+diff] = true end
            if k == "0-0" then
                new[k] = newv
            else
                local s, e = k:match "^(%d+)-(%d+)$"
                s = tonumber(s)+1
                e = tonumber(e)+1
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
        ev.emit('breakpoint', 'changed', {
            id = bp.id,
            message = "The source file has no line information.",
            verified = false,
        })
    end
end

function m.set_bp(clientsrc, breakpoints, content)
    local srcarray = source.c2s(clientsrc)
    if srcarray then
        local ok = false
        for _, src in ipairs(srcarray) do
            if calcLineInfo(src, content) then
                verifyBreakpoint(src, breakpoints)
                ok = true
            end
        end
        if not ok then
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
        stdout(res, info)
        return false
    end
    return true
end

function m.newproto(proto, src, key)
    src.protos[proto] = key
    do
        local bpkey = bpClientKey(src)
        local wv = waitverify[bpkey]
        if wv then
            if not src.content then
                waitverify[bpkey] = nil
            end
            if calcLineInfo(src, wv.content) then
                verifyBreakpoint(src, wv.breakpoints)
            else
                cantVerifyBreakpoints(wv.breakpoints)
            end
            return
        end
    end
    local bpkey = bpKey(src)
    local bps = currentactive[bpkey]
    if bps and src.lineinfo then
        updateBreakpoint(bpkey, src, bps)
        return
    end
end

local funcs = {}
function m.set_funcbp(breakpoints)
    funcs = {}
    for _, bp in ipairs(breakpoints) do
        local ok, err = evaluate.verify(bp.name)
        if not ok then
            ev.emit('breakpoint', 'changed', {
                id = bp.id,
                message = NormalizeErrorMessage("Error", err),
                verified = false,
            })
            goto continue
        end
        if not valid(bp) then
            goto continue
        end
        funcs[#funcs+1] = bp
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
        local ok, res = evaluate.eval(bp.name, 1)
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
            local ok, res = evaluate.eval(bp.condition, level, { error = error })
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
        local ok, err = evaluate.verify(filter.condition)
        if not ok then
            ev.emit('breakpoint', 'changed', {
                id = filter.id,
                message = NormalizeErrorMessage("Error", err),
                verified = false,
            })
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
