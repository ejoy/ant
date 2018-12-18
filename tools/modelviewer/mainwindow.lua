dofile "libs/init.lua"

local elog = require "editor.log"
local inputmgr = require "inputmgr"
local mapiup = require "editor.input.mapiup"
local bgfx = require "bgfx"
local rhwi = require "render.hardware_interface"
local scene = require "scene.util"
local eu = require "editor.util"
local task = require "editor.task"
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

local input_queue = inputmgr.queue(mapiup)
eu.regitster_iup(input_queue, canvas)

dlg:showxy(iup.CENTER, iup.CENTER)
dlg.usersize = nil

rhwi.init {
	nwh = iup.GetAttributeData(canvas,"HWND"),
	width = fb_width,
	height = fb_height,
}

local world = scene.start_new_world(input_queue, fb_width, fb_height, {
	"renderworld",
	"camera_controller",
}, "?.lua;tools/modelviewer/?.lua")

task.loop(world.update)

if iup.MainLoopLevel() == 0 then
	iup.MainLoop()
	iup.Close()
	bgfx.shutdown()
end
