dofile "libs/init.lua"

require "scintilla"

local bgfx = require "bgfx"
local ecs = require "ecs"
local inputmgr = require "inputmgr"
local mapiup = require "inputmgr.mapiup"
local elog = require "editor.log"
local db = require "debugger"
local hw_caps = require "render.hardware_caps"
local task = require "editor.task"

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

local function init()
	local function bgfx_init()
		local args = {
			nwh = iup.GetAttributeData(canvas,"HWND"),
			renderer = nil	-- use default
		}
		bgfx.set_platform_data(args)
		bgfx.init(args)

		hw_caps.init()
	end
	bgfx_init()

	world = ecs.new_world {
		modules = {
			assert(loadfile "test/system/simple_system.lua"),
		},
		args = { mq = input_queue },
	}
	task.loop(world.update,
	function ()
		local trace = db.traceback()
		elog.print(trace)
		elog.active_error()
	end)
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

iup.MainLoop()
iup.Close()
bgfx.shutdown()
