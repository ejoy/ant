dofile "libs/init.lua"

local bgfx = require "bgfx"
local inputmgr = require "inputmgr"
local mapiup = require "inputmgr.mapiup"
local rhwi = require "render.hardware_interface"
local elog = require "editor.log"
local scene = require "scene.util"

iup.SetGlobal("UTF8MODE", "YES")

local fb_width = 1280
local fb_height = 720

local canvas = iup.canvas {
	rastersize = fb_width .. "x" .. fb_height
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

dlg:showxy(iup.CENTER,iup.CENTER)
dlg.usersize = nil

local function init(nwh, fbw, fbh, iq)
	rhwi.init(nwh, fbw, fbh)
	scene.start_new_world(iq, fbw, fbh, "test_world.module")
end

init(iup.GetAttributeData(canvas,"HWND"), 
	fb_width, fb_height,
	inputmgr.queue(mapiup, canvas))

-- to be able to run this script inside another context
if (iup.MainLoopLevel()==0) then
	iup.MainLoop()
	iup.Close()
	bgfx.shutdown()	
end
