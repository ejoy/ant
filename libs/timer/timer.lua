local ecs = ...

local timer = ecs.component "timer"

function timer:init()
	self.previous = 0
	self.delta = 0
	self.current = 0
end

local timesystem = ecs.system "timesystem"
timesystem.singleton "timer"

local baselib = require "bgfx.baselib"

function timesystem:update()
	local timer = self.timer
	local current = baselib.HP_time()		
	if timer.previous == 0 then
		timer.previous = current
	else
		timer.previous = timer.current
	end

	timer.current = current
	timer.delta = timer.current - timer.previous
end