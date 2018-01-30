dofile "libs/init.lua"

require "scintilla"
local lbgfx = require "lbgfx"
local bgfx = require "bgfx"
local ecs = require "ecs"
local inputmgr = require "inputmgr"
local mapiup = require "inputmgr.mapiup"
local elog = require "editor.log"
local redirect = require "filesystem.redirect"

iup.SetGlobal("UTF8MODE", "YES")

local canvas = iup.canvas {
	rastersize = "1024x768",
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
local world

input_queue:register_iup(canvas)

local function mainloop()
	redirect.dispatch()
	world.update()
end

local function init()
	lbgfx.init {
		nwh = iup.GetAttributeData(canvas,"HWND"),
	}
	world = ecs.new_world {
		modules = { 
			assert(loadfile "test/cameratest/camera_component.lua"),
			assert(loadfile "test/cameratest/camera_system.lua"),
			assert(loadfile "test/simple_system.lua"),
		},
		args = { mq = input_queue },
	}
	lbgfx.mainloop(mainloop)
end

function canvas:resize_cb(w,h)
	if init then
		init(self)
		init = nil
	end
	input_queue:push("resize", w, h)
	print("RESIZE",w,h)
end

function canvas:action(x,y)
	mainloop()
end


dlg:showxy(iup.CENTER,iup.CENTER)
dlg.usersize = nil

-- to be able to run this script inside another context
if (iup.MainLoopLevel()==0) then
	iup.MainLoop()
	iup.Close()
	lbgfx.shutdown()
end
