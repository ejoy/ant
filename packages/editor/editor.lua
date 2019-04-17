-- luacheck: globals iup
-- luacheck: ignore self, ignore world

require "iuplua"

local rhwi = import_package "ant.render".hardware_interface
local su = import_package "ant.scene".util
local inputmgr = import_package "ant.inputmgr"
local mapiup = require "mapiup"
local task = require "task"

local editor = {}; editor.__index = editor

local world

function editor.run(fbw, fbh, canvas, packages, systems)	
	rhwi.init {
		nwh = iup.GetAttributeData(canvas,"HWND"),
		width = fbw,
		height = fbh,
		getlog = false,
	}
	
	local iq = inputmgr.queue()	
	mapiup(iq, canvas)

	world = su.start_new_world(iq, fbw, fbh, packages, systems)
	task.loop(su.loop(world, {
		update = {"timesystem", "message_system"},
	}), function (co, status)
		iup.Message("Error", string.format("Error:%s\n%s", status, debug.traceback(co)))
	end)

	if (iup.MainLoopLevel()==0) then
		iup.MainLoop()
		iup.Close()
	end
end

return editor