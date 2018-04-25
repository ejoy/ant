dofile "libs/init.lua"

require "scintilla"

local bgfx = require "bgfx"
local ecs = require "ecs"
local inputmgr = require "inputmgr"
local mapiup = require "inputmgr.mapiup"
local elog = require "editor.log"
local db = require "debugger"
local rhwi = require "render.hardware_interface"
local scene = require "scene.util"
local task = require "editor.task"
local au = require "asset.util"

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
local world

input_queue:register_iup(canvas)

local function init()
	rhwi.init(iup.GetAttributeData(canvas,"HWND"), 1280, 720)
	local module_description_file = "mem://simple.module"
	au.write_to_file([[module = {"test/system/simple_system.lua"}]])
	scene.start_new_world(input_queue, module_description_file)
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
