dofile "libs/init.lua"

local lbgfx = require "lbgfx"
local bgfx = require "bgfx"
local ecs = require "ecs"
local inputmgr = require "inputmgr"
local mapiup = require "inputmgr.mapiup"

local canvas = iup.canvas {}

local dlg = iup.dialog {
	canvas,
	title = "simple",
	size = "HALFxHALF",
}

local input_queue = inputmgr.queue(mapiup)
local world

input_queue:register_iup(canvas)

local function mainloop()
	world.update()
end

local function init()
	lbgfx.init {
		nwh = iup.GetAttributeData(canvas,"HWND"),
	}
	world = ecs.new_world {
		modules = { assert(loadfile "test/simple_system.lua") },
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



