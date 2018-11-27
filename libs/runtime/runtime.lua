require 'runtime.vfs'
require 'runtime.vfsio'
require 'runtime.errlog'

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

local width = 1024
local height = 768
local nwh = native.create(width,height,"Hello World")

local inputmgr = require "inputmgr"
local iq = inputmgr.queue {
	button = "_,_,_,_,_",
	motion = "_,_,_",
	keypress="_,_,_",
}

local callback = {}

function callback.error(err)
	print(err)
end

local status = {}
function callback.move(x,y)
	iq:push("motion", x, y, status)
end

function callback.mouse(what, press, x, y)
	local function translate()
		if what == 0 then
			status.LEFT = press
			return "LEFT"
		elseif what == 1 then
			status.RIGHT = press
			return "RIGHT"
		else
			return ""
		end
	end
	local btn = translate()
	iq:push("button", btn, press, x, y)
end

function callback.keypress(key, press, state)
	local function what_state(state, bit)
		if state & bit then
			return true
		end		
	end
	local status = {}
	status['CTRL'] = what_state(state, 0x01)
	status['ALT'] = what_state(state, 0x02)
	status['SHIFT'] = what_state(state, 0x04)
	status['SYS'] = what_state(state, 0x08)

	iq:push("keypress", key, press, status)
end

function callback.exit()	
    dprint("exit")
end

local function start(modules, modulepath)
    local su = require "scene.util"
    local rhwi = require "render.hardware_interface"
    rhwi.init(nwh, width, height)
    local world = su.start_new_world(iq, width, height, modules, modulepath)
    function callback.update()
        dbgupdate()
        world.update()
    end
    window.register(callback)
    native.mainloop()
end

return {
    start = start
}
