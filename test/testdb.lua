dofile "libs/init.lua"

local redirect = require "filesystem.redirect"
local elog = require "editor.log"
local debugger = require "debugger"
local inputmgr = require "inputmgr"
local mapiup = require "inputmgr.mapiup"

local canvas = iup.canvas { RASTERSIZE = "640x480" }
local input_queue = inputmgr.queue(mapiup)
input_queue:register_iup(canvas)

local dlg = iup.dialog {
	iup.split {
		canvas,
		elog.window,
		SHOWGRIP = "NO",
	},
	title = "testdb",
	shrink="yes",
}

local function mainloop(f)
	iup.SetIdle(function ()
		local ok , err = xpcall(f, debugger.traceback)
		if not ok then
			elog.print(err)
			elog.active_error()
			iup.SetIdle(redirect.dispatch)
		end
		return iup.DEFAULT
	end)
end

dlg:showxy(iup.CENTER,iup.CENTER)
dlg.usersize = nil
mainloop(function()
	for _,cmd,v2,v3 in pairs(input_queue) do
		if cmd == "button" then
			print(cmd, v2,v3)
			error "TEST"
		end
	end
	redirect.dispatch()
end)

-- to be able to run this script inside another context
if (iup.MainLoopLevel()==0) then
	iup.MainLoop()
	iup.Close()
end
