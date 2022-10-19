local ecs = ...

local ltask = require "ltask"

local function gettime()
    local _, now = ltask.now()
	return now * 10
end

local previous
local current = 0
local delta

local it = ecs.interface "itimer"

function it.current()
	return current
end

function it.delta()
	return delta
end

local time_sys = ecs.system "time_system"
function time_sys:init()
	current = gettime()
	previous = current
	delta = 0
end
function time_sys:timer()
	previous = current
	current = gettime()
	delta = current - previous
end
