dofile "libs/init.lua"

require "iuplua"
require "scintilla"

local bgfx = require "bgfx"

local inputmgr = require "inputmgr"
local mapiup = require "inputmgr.mapiup"
local elog = require "editor.log"

local rhwi = require "render.hardware_interface"
local scene = require "scene.util"
local eu = require "editor.util"
local task = require "editor.task"

local fs_util = require "filesystem.util"

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
	rhwi.init(iup.GetAttributeData(canvas,"HWND"), fbw, fbh)
	local world = scene.start_new_world(input_queue, fbw, fbh, {"test.system.simple_system"})
	task.loop(world.update)
end

dlg:showxy(iup.CENTER,iup.CENTER)
dlg.usersize = nil

init()

iup.MainLoop()
iup.Close()
bgfx.shutdown()
