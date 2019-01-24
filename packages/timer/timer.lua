local ecs = ...

local timer = ecs.singleton_component "timer"

function timer:init()
	return {
		previous = 0,
		delta = 0,
		current = 0,
	}
end

local timesystem = ecs.system "timesystem"
timesystem.singleton "timer"

local baselib = require "bgfx.baselib"

function timesystem:update()
	local timer = self.timer
	local current = baselib.HP_counter()	
	if timer.previous == 0 then
		timer.previous = current
	else
		timer.previous = timer.current
	end

	timer.current = current
	timer.delta = baselib.HP_time(timer.previous)
end