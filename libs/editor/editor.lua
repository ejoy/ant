-- luacheck: globals iup
-- luacheck: ignore self, ignore world

require "iuplua"

local rhwi = require "render.hardware_interface"
local su = require "scene.util"

local inputmgr = require "inputmgr"
local mapiup = require "editor.input.mapiup"

local task = require "editor.task"

local editor = {}; editor.__index = editor

function editor.run(fbw, fbh, canvas, modules, module_searchpath)	
	rhwi.init {
		nwh = iup.GetAttributeData(canvas,"HWND"),
		width = fbw,
		height = fbh,
		getlog = false,
	}
	local iq = inputmgr.queue(mapiup)
	local eu = require "editor.util"
	eu.regitster_iup(iq, canvas)
	local world = su.start_new_world(iq, fbw, fbh, modules, module_searchpath)

	task.loop(world.update)

	if (iup.MainLoopLevel()==0) then
		iup.MainLoop()
		iup.Close()
	end
end

return editor