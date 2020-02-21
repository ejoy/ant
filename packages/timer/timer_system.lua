local ecs = ...

local baselib      = require "bgfx.baselib"
local time_counter = baselib.HP_counter
local time_freq    = baselib.HP_frequency / 1000
local function gettime()
	return time_counter() / time_freq
end

local previous
local current = 0
local delta

local timer = ecs.interface "timer"
timer.require_system "timesystem"
function timer.current()
	return current
end
function timer.delta()
	return delta
end

local timesystem = ecs.system "timesystem"
function timesystem:init()
	current = gettime()
	previous = current
	delta = 0
end
function timesystem:timer()
	previous = current
	current = gettime()
	delta = current - previous
end
