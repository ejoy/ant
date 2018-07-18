dofile "libs/init.lua"

local redirect = require "filesystem.redirect"
local elog = require "editor.log"
local debugger = require "debugger"
local inputmgr = require "inputmgr"
local mapiup = require "inputmgr.mapiup"
local task = require "editor.task"
local eu = require "editor.util"

local canvas = iup.canvas { RASTERSIZE = "640x480" }
local input_queue = inputmgr.queue(mapiup)
eu.regitster_iup(input_queue, canvas)

local dlg = iup.dialog {
	iup.split {
		canvas,
		elog.window,
		SHOWGRIP = "NO",
	},
	title = "testdb",
	shrink="yes",
}

task.loop(redirect.dispatch, function(co)
	local trace = debug.traceback(co)
	elog.print(trace)
	elog.active_error()
end)

task.loop(function()
	for _,cmd,v2,v3 in pairs(input_queue) do
		print(cmd, v2,v3)
		if cmd == "button" then
			error "TEST"
		end
	end
end, function(co)
	local trace = debugger.traceback(co)
	elog.print(trace)
end)

dlg:showxy(iup.CENTER,iup.CENTER)
dlg.usersize = nil

iup.MainLoop()
iup.Close()
