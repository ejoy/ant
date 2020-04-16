local ecs = ...

local timer = require "platform.timer"
local time_counter = timer.counter
local time_freq    = timer.frequency() / 1000
local function gettime()
	return time_counter() / time_freq
end

local previous
local current = 0
local delta

local timer = ecs.interface "timer"

function timer.current()
	return current
end
function timer.delta()
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
