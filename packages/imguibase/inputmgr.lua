local im = {}

local mouse_what = {
	'LEFT', 'RIGHT', 'MIDDLE'
}

local mouse_state = {
	'DOWN', 'MOVE', 'UP'
}

function im.translate_mouse_button(what)
	return mouse_what[what] or "UNKNOWN"
end

function im.translate_mouse_state(state)
	return mouse_state[state] or "UNKNOWN"
end

function im.translate_key_state(state)
	return {
		CTRL 	= (state & 0x01) ~= 0,
		ALT 	= (state & 0x02) ~= 0,
		SHIFT 	= (state & 0x04) ~= 0,
		SYS 	= (state & 0x08) ~= 0,
	}
end

local keymap = require "keymap"

function im.translate_key(key)
	return keymap[key & 0x0FFFFFFF]
end

local translate = {
	Tab        = "TAB",
	LeftArrow  = "LEFT",
	RightArrow = "RIGHT",
	UpArrow    = "UP",
	DownArrow  = "DOWN",
	PageUp     = "PRIOR",
	PageDown   = "NEXT",
	Home       = "HOME",
	End        = "END",
	Insert     = "INSERT",
	Delete     = "DELETE",
	Backspace  = "BACK",
	Space      = "SPACE",
	Enter      = "RETURN",
	Escape     = "ESCAPE",
}

function im.init_keymap(imgui)
	local keys = imgui.keymap()
	local rev_keymap = {}
	for k, v in pairs(keymap) do
		rev_keymap[v] = k
	end
	local res = {}
	for _, key in ipairs(keys) do
		if translate[key] then
			res[key] = assert(rev_keymap[translate[key]])
		end
	end
	imgui.keymap(res)
end

im.keymap = keymap

return im
