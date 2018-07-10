local rdebug = require 'remotedebug'
local path = require 'new-debugger.path'
local source = require 'new-debugger.worker.source'
local hookmgr = require 'new-debugger.worker.hookmgr'
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
    hookmgr.openBP()
    enable = true

    local res = {}
    for _, bp in ipairs(bps) do
        bp.source = clientsrc
        res[bp.line] = bp
    end
    waitverify[path.normalize_native(clientsrc.path)] = bps
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
