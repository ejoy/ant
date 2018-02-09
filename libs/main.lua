dofile "libs/init.lua"

require "scintilla"

local bgfx = require "bgfx"
local ecs = require "ecs"
local inputmgr = require "inputmgr"
local mapiup = require "inputmgr.mapiup"
local elog = require "editor.log"
local redirect = require "filesystem.redirect"
local db = require "debugger"
local hw_caps = require "render.hardware_caps"

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

local function set_mainloop(f)
	iup.SetIdle(function ()
		local ok , err = xpcall(f, db.traceback)
		if not ok then
			elog.print(err)
			elog.active_error()
			iup.SetIdle(redirect.dispatch)
		end
		return iup.DEFAULT
	end)
end

local init_flag = nil

local function bgfx_init()
	assert(init_flag == nil)

	local args = {
		nwh = iup.GetAttributeData(canvas,"HWND"),
		renderer = nil	-- use default
	}
	bgfx.set_platform_data(args)
	bgfx.init(args.renderer)

	hw_caps.init()
end

local function init()
	bgfx_init()
	
	world = ecs.new_world {
		modules = { 
			assert(loadfile "libs/inputmgr/message_system.lua"),
			assert(loadfile "libs/render/add_entity_system.lua"),	
			assert(loadfile "libs/render/math3d/math_component.lua"),			
			assert(loadfile "libs/render/material/material_component.lua"),
			assert(loadfile "libs/render/mesh_component.lua"),
			assert(loadfile "libs/render/viewport_component.lua"),
			assert(loadfile "libs/render/camera/camera_component.lua"),
			assert(loadfile "libs/render/camera/camera_system.lua"),
			assert(loadfile "libs/render/renderpipeline.lua"),
		},
		args = { mq = input_queue },
	}
	set_mainloop(mainloop)	
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
	if init_flag then
		bgfx.shutdown()
	end
end
