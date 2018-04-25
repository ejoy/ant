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

input_queue:register_iup(canvas)

local function init()
	rhwi.init(iup.GetAttributeData(canvas,"HWND"), fb_width, fb_height)	
	scene.start_new_world(input_queue, "test_world.module")
end

function canvas:resize_cb(w,h)
	if init then
		init(self)
		init = nil
	end
	input_queue:push("resize", w, h)
	print("RESIZE",w,h)
end

dlg:showxy(iup.CENTER,iup.CENTER)
dlg.usersize = nil

-- to be able to run this script inside another context
if (iup.MainLoopLevel()==0) then
	iup.MainLoop()
	iup.Close()
	if init_flag then
		bgfx.shutdown()
	end
end
