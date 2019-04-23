require 'runtime.vfs'
require 'runtime.errlog'
local LOGERROR = log.error

import_package = require "antpm".import

require "filesystem"

local keymap = import_package "ant.inputmgr".keymap

local dbgupdate = require 'runtime.debug'

dprint = print

require "common/log"

local native = require "window.native"
local window = require "window"

local inputmgr = import_package "ant.inputmgr"
local iq = inputmgr.queue()

local mouse_status = {
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
local packages, systems
local world
local world_update

function callback.init(nwh, context, w, h)
	width, height = w, h
    local su = import_package "ant.scene".util
    local rhwi = import_package "ant.render".hardware_interface
    rhwi.init {
		nwh = nwh,
		context = context,
		width = width,
		height = height,
	}
	world = su.start_new_world(iq, width, height, packages, systems)
	world_update = su.loop(world, {
		update = {"timesystem", "message_system"}
	})
end

function callback.error(err)
	LOGERROR(err)
end

function callback.mouse_move(x, y, state)
	iq:push("mouse_move", x, y, mouse_status[(state & 7) + 1])
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
	iq:push("keyboard", keymap[key], press, status)
end

function callback.exit()
    dprint("exit")
end

function callback.update()
	dbgupdate()
	if world_update then
		world_update()
	end
end

local function start(m1, m2)
	packages, systems = m1, m2
	window.register(callback)
	native.create(1024, 768, "Hello")
    native.mainloop()
end

return {
    start = start
}
