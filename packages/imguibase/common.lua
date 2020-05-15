local m = {}

function m.init_world(w)
	import_package "ant.asset".init()

	local keymap      = import_package "ant.imguibase".keymap
	local mouse_what  = { 'LEFT', 'RIGHT', 'MIDDLE' }
	local mouse_state = { 'DOWN', 'MOVE', 'UP' }
	w:signal_on("mouse", function(x, y, what, state)
		w:pub {"mouse", mouse_what[what] or "UNKNOWN", mouse_state[state] or "UNKNOWN", x, y}
	end)
	w:signal_on("keyboard", function(key, press, state)
		w:pub {"keyboard", keymap[key], press, {
			CTRL	= (state & 0x01) ~= 0,
			ALT		= (state & 0x02) ~= 0,
			SHIFT	= (state & 0x04) ~= 0,
			SYS		= (state & 0x08) ~= 0,
		}}
	end)
	w:signal_on("mouse_wheel", function(x, y, delta)
		w:pub {"mouse_wheel", delta, x, y}
	end)
	w:signal_on("touch", function(x, y, id, state)
		w:pub {"touch", state, id, x, y}
	end)
end

return m
