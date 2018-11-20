dofile "libs/init.lua"

local elog = require "editor.log"
local inputmgr = require "inputmgr"
local mapiup = require "inputmgr.mapiup"
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

rhwi.init(iup.GetAttributeData(canvas,"HWND"), fb_width, fb_height)

local world = scene.start_new_world(input_queue, fb_width, fb_height, {
	"modelloader.renderworld",
	"modelloader.camera_controller",
})

task.loop(world.update)

if iup.MainLoopLevel() == 0 then
	iup.MainLoop()
	iup.Close()
	bgfx.shutdown()
end
