local baselib = require "bgfx.baselib"

local timer = {
	previous_counter=0,
	current_counter=0,
	-- in ms
	deltatime=0,
}; 

timer.__index = timer

local freq = baselib.HP_frequency

function timer.from_counter(counter, unit)
	unit = unit or 1000
	return (counter / freq) * unit
end

function timer.get_sys_counter()
	return baselib.HP_counter()
end

function timer.cur_time()
    return timer.from_counter(timer.get_sys_counter())
end

return timer