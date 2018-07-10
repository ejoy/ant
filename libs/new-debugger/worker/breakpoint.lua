local rdebug = require 'remotedebug'
local path = require 'new-debugger.path'
local source = require 'new-debugger.worker.source'
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

local function verifyBreakpoint(src, bps)
    local res = {}
    for _, bp in ipairs(bps) do
        local activeline = nextActiveLine(src, bp.line)
        if activeline then
            bp.source = src
            bp.line = activeline
            res[bp.line] = bp
            ev.emit('breakpoint', 'changed', {
                id = bp.id,
                line = bp.line,
                verified = true,
            })
        end
    end
    local normalizePath = path.normalize_native(src.path)
    local oldBP = breakpoints[normalizePath]
    if next(res) == nil then
        breakpoints[normalizePath] = nil
    else
        breakpoints[normalizePath] = res
    end
    if enable then
        if next(breakpoints) == nil then
            --TODO rdebug.hookmask ''
            rdebug.hookmask 'cr'
            enable = false
        end
    else
        if next(breakpoints) ~= nil then
            rdebug.hookmask 'cr'
            enable = true
        end
    end
    if currentBP and currentBP == oldBP then
        m.reset()
    end
end

function m.reset()
    currentBP = nil
    rdebug.hookmask 'crl'
end

function m.find(currentline)
	if not currentBP then
        local s = rdebug.getinfo(1, info)
        local src = source.create(s.source)
        if not source.valid(src) then
			rdebug.hookmask 'cr'
			return
        end
        if src.path then
            currentBP = breakpoints[path.normalize_native(src.path)]
        else
            currentBP = breakpoints[src.ref]
        end
		if not currentBP then
			rdebug.hookmask 'cr'
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
    local res = {}
    for _, bp in ipairs(bps) do
        bp.source = clientsrc
        res[bp.line] = bp
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

    verifyBreakpoint(src, bps)
end)

return m
