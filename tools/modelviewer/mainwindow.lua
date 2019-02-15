local packages = {
	"ant.modelviewer"
}
local systems = {
	"model_review_system",
	"camera_controller",
}

if __ANT_RUNTIME__ then
	local rt = require "runtime"
	rt.start(packages, systems)
	return
end

local elog = import_package "ant.iupcontrols" .logview
local inputmgr = import_package "ant.inputmgr"
local bgfx = require "bgfx"
local rhwi = import_package "ant.render".hardware_interface
local scene = import_package "ant.scene"
local editor = import_package "ant.editor"
local mapiup = editor.mapiup
local task = editor.task
require "iuplua"

local fb_width, fb_height = 1024, 768
local canvas = iup.canvas {
	rastersize = fb_width .. "x" .. fb_height
}

local dlg = iup.dialog {
	iup.split {
		canvas,
		elog.window,
		SHOWGRIP = "NO",
	},
	margin = "4x4",
	size = "HALFxHALF",
	shrink = "Yes",
	title = "Model",
}

local input_queue = inputmgr.queue()
mapiup(input_queue, canvas)

dlg:showxy(iup.CENTER, iup.CENTER)
dlg.usersize = nil

rhwi.init {
	nwh = iup.GetAttributeData(canvas,"HWND"),
	width = fb_width,
	height = fb_height,
}

local world = scene.start_new_world(input_queue, fb_width, fb_height, packages, systems)
local update = world:update_func("update", {"timesystem", "message_system"})
task.loop(update)

if iup.MainLoopLevel() == 0 then
	iup.MainLoop()
	iup.Close()
	bgfx.shutdown()
end
