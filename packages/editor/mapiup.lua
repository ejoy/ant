local keymap = (import_package "ant.inputmgr").keymap

local status_map = {
	["1"] = "LEFT",
	["2"] = "MIDDLE",
	["3"] = "RIGHT",
	["4"] = "BUTTON4",
	["5"] = "BUTTON5",
	A = "ALT",
	C = "CTRL",
	Y = "SYS",
	S = "SHIFT",
	D = "DOUBLE",
}

local function translate_status(status)
	local t = {}
	for i = 1, #status do	
		local n = status:sub(i, i)
		local v = status_map[n]
		if v then
			t[v] = true
		end
	end
	return t
end

local pressnames = {
	[0] = false,
	[1] = true,
}

local buttonnames = { 
	['1'] = "LEFT",
	['2'] = "MIDDLE",
	['3'] = "RIGHT",
	['4'] = "BUTTON4",
	['5'] = "BUTTON5"
}

local iupmap = {
	[10] = 'RETURN',		-- \n
	[33] = '1',				-- !
	[34] = 'OEM_7',			-- "
	[35] = '3',				-- #
	[36] = '4',				-- $
	[37] = '5',				-- %
	[38] = '7',				-- &
	[39] = 'OEM_7',			-- '
	[40] = '9',				-- (
	[41] = '0',				-- )
	[42] = '8',				-- *
	[43] = 'OEM_PLUS',		-- +
	[44] = 'OEM_COMMA',		-- ,
	[45] = 'OEM_MINUS',		-- -
	[46] = 'OEM_PERIOD',	-- .
	[47] = 'OEM_2',			-- /
	[58] = 'OEM_1',			-- :
	[59] = 'OEM_1',			-- ;
	[60] = 'OEM_COMMA',		-- <
	[61] = 'OEM_PLUS',		-- =
	[62] = 'OEM_PERIOD',	-- >
	[63] = 'OEM_2',			-- ?
	[64] = '2',				-- @
	[91] = 'OEM_4',			-- [
	[92] = 'OEM_5',			-- \
	[93] = 'OEM_6',			-- ]
	[94] = '6',				-- ^
	[95] = 'OEM_MINUS',		-- _
	[96] = 'OEM_3',			-- `
	[123] = 'OEM_4',		-- {
	[124] = 'OEM_5',		-- |
	[125] = 'OEM_6',		-- }
	[126] = 'OEM_3',		-- ~

	[0xFF0B] = 'CLEAR',
	[0xFF13] = 'PAUSE',
	[0xFF14] = 'NUMLOCK',
	[0xFF1B] = 'ESCAPE',
	[0xFF50] = 'HOME',
	[0xFF51] = 'LEFT',
	[0xFF52] = 'UP',
	[0xFF53] = 'RIGHT',
	[0xFF54] = 'DOWN',
	[0xFF55] = 'PRIOR',
	[0xFF56] = 'NEXT',
	[0xFF57] = 'END',
	[0xFF61] = 'PRINT',
	[0xFF63] = 'INSERT',
	[0xFF67] = 'APPS',
	[0xFF7F] = 'CAPITAL',
	[0xFFBE] = 'F1',
	[0xFFBF] = 'F2',
	[0xFFC0] = 'F3',
	[0xFFC1] = 'F4',
	[0xFFC2] = 'F5',
	[0xFFC3] = 'F6',
	[0xFFC4] = 'F7',
	[0xFFC5] = 'F8',
	[0xFFC6] = 'F9',
	[0xFFC7] = 'F10',
	[0xFFC8] = 'F11',
	[0xFFC9] = 'F12',
	[0xFFE1] = 'SHIFT',
	[0xFFE2] = 'SHIFT',
	[0xFFE3] = 'CONTROL',
	[0xFFE4] = 'CONTROL',
	[0xFFE5] = 'SCROLL',
	[0xFFE9] = 'MENU',
	[0xFFEA] = 'MENU',
	[0xFFFF] = 'DELETE',
}

return function (msgqueue, ctrl)	
	ctrl.button_cb = function(_, btn, press, x, y, status)
		msgqueue:push("mouse_click", buttonnames[string.char(btn)], pressnames[press], x, y, translate_status(status))
	end

	ctrl.motion_cb = function(_, x, y, status)
		msgqueue:push("mouse_move", x, y, translate_status(status))
	end

	ctrl.wheel_cb = function(_, delta, x, y, status)
		-- not use status right now
		msgqueue:push("mouse_wheel", x, y, delta)
	end

	ctrl.keypress_cb = function(_, key, press)
		msgqueue:push("keyboard", iupmap[key & 0x0FFFFFFF] or keymap[key & 0x0FFFFFFF], pressnames[press], {
			SHIFT = (key | 0x10000000) ~= 0,
			CTRL  = (key | 0x20000000) ~= 0,
			ALT   = (key | 0x40000000) ~= 0,
			SYS   = (key | 0x80000000) ~= 0,
		})
	end
	ctrl.resize_cb = function(_, a, b)
		msgqueue:push("resize", a, b)
	end
end