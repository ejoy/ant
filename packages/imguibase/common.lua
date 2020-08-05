local keymap   = require "keymap"
local assetmgr = import_package "ant.asset"

local m = {}

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

function m.init_world(w)
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

function m.init_imgui(imgui)
	local imgui_font = assetmgr.load_fx {
		fs = "/pkg/ant.imguibase/shader/fs_imgui_font.sc",
		vs = "/pkg/ant.imguibase/shader/vs_imgui_font.sc",
	}
	imgui.ant.font_program(
		imgui_font.prog,
		imgui_font.uniforms[1].handle
	)
	local imgui_image = assetmgr.load_fx {
		fs = "/pkg/ant.imguibase/shader/fs_imgui_image.sc",
		vs = "/pkg/ant.imguibase/shader/vs_imgui_image.sc",
	}
	imgui.ant.image_program(
		imgui_image.prog,
		imgui_image.uniforms[1].handle
	)

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

return m
