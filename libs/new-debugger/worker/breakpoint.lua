local rdebug = require 'remotedebug'
local path = require 'new-debugger.path'
local source = require 'new-debugger.worker.source'

local breakpoints = {}

local info = {}
local emitEvent
local currentBP
local realBP

local m = {}

function m.reset()
    realBP = nil
    currentBP = nil
    rdebug.hookmask "crl"
end

local function nextActiveLine(actives, line)
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

function m.update(src, bps)
    if not src.path then
        return
    end
    local res = {}
    for _, bp in ipairs(bps) do
        res[bp.line] = bp

        bp.verified = true
        bp.source = src
        emitEvent('new', bp)
    end
    local normalizePath = path.normalize(src.path, '/', string.lower)
    if realBP and realBP == breakpoints[normalizePath] then
        m.reset()
    end
    breakpoints[normalizePath] = res
end

function m.event(f)
    emitEvent = f
end

return m
