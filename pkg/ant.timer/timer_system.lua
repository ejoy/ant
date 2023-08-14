local ecs = ...

local ltask = require "ltask"

local function gettime()
    local _, now = ltask.now()
	return now * 10
end

local previous
local current = 0
local delta

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

local m = {}

function m.current()
	return current
end

function m.delta()
	return delta
end

return m
