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

im.keymap = keymap

return im
