local ecs = ...
local world = ecs.world

local now
local delta
local pause

local time_sys = ecs.system "time_system"

function time_sys:init()
	now = 0
	delta = 0
end

function time_sys:timer()
	if pause then
		delta = 0
	else
		delta = world:get_frame_time()
		now = now + delta
	end
end

local m = {}

function m.delta()
	return delta
end

function m.now()
	return now
end

function m.pause()
	pause = true
end

function m.continue()
	pause = false
end

return m
