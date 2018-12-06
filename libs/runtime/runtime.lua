require 'runtime.vfs'
require 'runtime.vfsio'
require 'runtime.errlog'

local keymap = require 'inputmgr.keymap'

local dbgupdate = require 'runtime.debug'

function dprint(...)
	print(...)
	local nio = package.loaded.nativeio or io	
	nio.stdout:flush()
end

require "common/import"
require "common/log"

local native = require "window.native"
local window = require "window"

local inputmgr = require "inputmgr"
local iq = inputmgr.queue {
	keyboard="_,_,_",
	mouse_click = "_,_,_,_,_",
	mouse_move = "_,_,_",
	mouse_wheel="_,_,_",
}

local mouse_move_status = {
	{},
	{ LEFT = true },
	{ RIGHT = true },
	{ LEFT = true, RIGHT = true },
	{ MIDDLE = true },
	{ LEFT = true, MIDDLE = true },
	{ RIGHT = true, MIDDLE = true },
	{ LEFT = true, RIGHT = true, MIDDLE = true },
}

local mouse_click_what = {
	'LEFT', 'RIGHT', 'MIDDLE'
}

local function what_state(state, bit)
	if state & bit ~= 0 then
		return true
	end		
end

local callback = {}

local width, height
local modules, modulepath

local function update()
end

function callback.init(window, context, w, h)
	width, height = w, h
    local su = require "scene.util"
    local rhwi = require "render.hardware_interface"
    rhwi.init(window, width, height)
	local world = su.start_new_world(iq, width, height, modules, modulepath)
	function update()
		dbgupdate()
		world.update()
	end
end

function callback.error(err)
	print(err)
end

function callback.mouse_move(x, y, state)
	iq:push("mouse_move", x, y, mouse_move_status[(state & 7) + 1])
end

function callback.mouse_wheel(x, y, delta)
	iq:push("mouse_wheel", delta, x, y)
end

function callback.mouse_click(x, y, what, press)
	iq:push("mouse_click", mouse_click_what[what + 1] or 'UNKNOWN', press, x, y)
end

function callback.keyboard(key, press, state)
	local status = {}
	status['CTRL'] = what_state(state, 0x01)
	status['ALT'] = what_state(state, 0x02)
	status['SHIFT'] = what_state(state, 0x04)
	status['SYS'] = what_state(state, 0x08)
	local keyname = keymap.name(key)
	iq:push("keyboard", keyname, press, status)
end

function callback.exit()	
    dprint("exit")
end

function callback.update()
	update()
end

local function start(m1, m2)
	modules, modulepath = m1, m2
	window.register(callback)
	native.create(1024, 768, "Hello")
    native.mainloop()
end

return {
    start = start
}
