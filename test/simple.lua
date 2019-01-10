dofile "libs/init.lua"

require "iuplua"
require "scintilla"

local bgfx = require "bgfx"

local inputmgr = import_package "ant.inputmgr"
local mapiup = require "editor.input.mapiup"
local elog = require "editor.log"

local rhwi = require "render.hardware_interface"
local scene = import_package "ant.scene"
local eu = require "editor.util"
local task = require "editor.task"

local fs = require "filesystem"

iup.SetGlobal("UTF8MODE", "YES")

local fb_width, fb_height = 1024, 768

local canvas = iup.canvas {
	rastersize = fb_width .. "x" .. fb_height
--	size = "HALFxHALF",
}

local dlg = iup.dialog {
	iup.split {
		canvas,
		elog.window,
		SHOWGRIP = "NO",
	},
	title = "simple",
	shrink="yes",	-- logger box should be allow shrink
}

local input_queue = inputmgr.queue(mapiup)
eu.regitster_iup(input_queue, canvas)

local function init()
	local fbw, fbh = 1280, 720
	rhwi.init {
		nwh = iup.GetAttributeData(canvas,"HWND"),
		width = fbw,
		height = fbh,
	}
	local world = scene.start_new_world(input_queue, fbw, fbh, {"test.system.simple_system"})
	task.loop(world.update)
end

dlg:showxy(iup.CENTER,iup.CENTER)
dlg.usersize = nil

init()

iup.MainLoop()
iup.Close()
bgfx.shutdown()
