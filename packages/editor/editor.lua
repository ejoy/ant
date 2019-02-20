-- luacheck: globals iup
-- luacheck: ignore self, ignore world

require "iuplua"

local rhwi = import_package "ant.render".hardware_interface
local su = import_package "ant.scene"
local inputmgr = import_package "ant.inputmgr"
local mapiup = require "mapiup"
local task = require "task"

local editor = {}; editor.__index = editor

function editor.run(fbw, fbh, canvas, packages, systems)	
	rhwi.init {
		nwh = iup.GetAttributeData(canvas,"HWND"),
		width = fbw,
		height = fbh,
		getlog = false,
	}
	
	local iq = inputmgr.queue()	
	mapiup(iq, canvas)

	local world = su.start_new_world(iq, fbw, fbh, packages, systems)
	task.loop(su.loop{
		update = {"timesystem", "message_system"},
	})

	if (iup.MainLoopLevel()==0) then
		iup.MainLoop()
		iup.Close()
	end
end

return editor