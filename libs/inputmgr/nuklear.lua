local nkmsg = {}

local map = {}

function map.motion(x, y)
	return 'm', x, y
end

local button_map = {
	LEFT = 0,	-- NK_BUTTON_LEFT
	MIDDLE = 1,	-- NK_BUTTON_MIDDLE
	RIGHT = 2,	-- NK_BUTTON_RIGHT,
}

function map.button(btn, pressed, x, y, status)
	local id = button_map[btn]
	if not id then
		return
	end
	if btn == "LEFT" and status.DOUBLE then
		return 3, pressed, x, y	-- NK_BUTTON_DOUBLE
	end
	return 'b', id, pressed, x, y
end

function nkmsg.push(set, msg, ...)
	local f = map[msg]
	if f then
		local temp = { f(...) }
		if #temp > 1 then
			table.insert(set, temp)
		end
	end
end

return nkmsg
