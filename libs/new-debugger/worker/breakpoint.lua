local rdebug = require 'remotedebug'
local path = require 'new-debugger.path'
local source = require 'new-debugger.worker.source'
local ev = require 'new-debugger.event'

local breakpoints = {}

local info = {}
local currentBP
local realBP
local m = {}

local ID = 0
local function generateID()
    ID = ID + 1
    return ID
end

function m.reset()
    realBP = nil
    currentBP = nil
    rdebug.hookmask "crl"
end

local function nextActiveLine(actives, line)
    if line > actives.max then
        return
    end
    while actives[line] ~= true do
        line = line + 1
    end
    return line
end

function m.find(currentline)
	if not currentBP then
        local s = rdebug.getinfo(1, info)
        local src = source.create(s.source)
        if not source.valid(src) then
			rdebug.hookmask "cr"
			return
        end
        if src.path then
            realBP = breakpoints[path.normalize(src.path, '/', string.lower)]
        else
            realBP = breakpoints[src.ref]
        end
		if not realBP then
			rdebug.hookmask "cr"
			return
        end
        currentBP = {}
        local capture = false
		local linedefined = s.linedefined
		local lastlinedefined = s.lastlinedefined
        for line, func in pairs(realBP) do
            if linedefined == 0 or (line >= linedefined and line <= lastlinedefined) then
                local activeline = nextActiveLine(src.activelines, line)
                if activeline then
                    currentBP[activeline] = func
                    capture = true
                end
            end
        end
        if not capture then
            rdebug.hookmask "cr"
            return false
        end
	end
	return currentBP[currentline]
end

local waitverify = {}

function m.update(clientsrc, bps)
    if not clientsrc.path then
        return
    end
    local src = source.open(clientsrc.path)
    if src then
        local res = {}
        for _, bp in ipairs(bps) do
            local activeline = nextActiveLine(src.activelines, bp.line)
            if activeline then
                bp.source = src
                bp.line = activeline
                res[bp.line] = bp
                bp.verified = true
                bp.id = generateID()
                ev.emit('breakpoint', 'changed', bp)
            else
                bp.source = src
                bp.verified = false
                bp.id = generateID()
                res[bp.line] = bp
                ev.emit('breakpoint', 'changed', bp)
            end
        end
        local normalizePath = path.normalize_native(src.path)
        if realBP and realBP == breakpoints[normalizePath] then
            m.reset()
        end
        breakpoints[normalizePath] = res
        return
    end
    local res = {}
    for _, bp in ipairs(bps) do
        res[bp.line] = bp
        bp.verified = false
        bp.source = clientsrc
        ev.emit('breakpoint', 'new', bp)
    end
    waitverify[clientsrc.path] = bps
end

ev.on('source-create', function(src)
    if not src.path then
        return
    end
    if not waitverify[src.path] then
        return
    end
    local bps = waitverify[src.path]
    waitverify[src.path] = nil

    local res = {}
    for _, bp in ipairs(bps) do
        local activeline = nextActiveLine(src.activelines, bp.line)
        if activeline then
            bp.line = activeline
            res[bp.line] = bp
            bp.verified = true
            ev.emit('breakpoint', 'changed', {
                id = bp.id,
                line = bp.line,
                verified = true,
            })
        end
    end
    local normalizePath = path.normalize_native(src.path)
    if realBP and realBP == breakpoints[normalizePath] then
        m.reset()
    end
    breakpoints[normalizePath] = res
end)

return m
