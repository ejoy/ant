local ecs = ...
local timer = require "timer"

local timesystem = ecs.system "timesystem"
timesystem.step "timer"
local baselib = require "bgfx.baselib"

function timesystem:update()
	local current_counter = baselib.HP_counter()
	if timer.previous_counter == 0 then
		timer.previous_counter = current_counter
	else
		timer.previous_counter = timer.current_counter
	end

	timer.current_counter = current_counter
	timer.deltatime = timer.from_counter(current_counter - timer.previous_counter)
end