local rdebug = require 'remotedebug'
local path = require 'new-debugger.path'
local source = require 'new-debugger.worker.source'

local breakpoints = {}

local info = {}
local currentBP
local emitEvent

local m = {}

function m.find(currentline)
	if not currentBP then
        local s = rdebug.getinfo(1, info)
        local src = source.create(s.source)
        if not source.valid(src) then
			rdebug.hookmask "cr"
			return
        end
        if src.path then
            currentBP = breakpoints[path.normalize(src.path, '/', string.lower)]
        else
            currentBP = breakpoints[src.ref]
        end
		if not currentBP then
			rdebug.hookmask "cr"
			return
		else
            local linedefined = s.linedefined
            local lastlinedefined = s.lastlinedefined
			local capture = false
			for line, func in pairs(currentBP) do
				if line >= linedefined and line <= lastlinedefined then
					local activeline = rdebug.activeline(line)
					if activeline == nil then
						currentBP[line] = nil
					else
						if activeline ~= line then
							currentBP[line] = nil
							currentBP[activeline] = func
						end
						capture = true
					end
				end
			end
			if not capture then
				rdebug.hookmask "cr"
				return
			end
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
    if currentBP and currentBP == breakpoints[normalizePath] then
        currentBP = nil
    end
    breakpoints[normalizePath] = res
end

function m.event(f)
    emitEvent = f
end

return m
