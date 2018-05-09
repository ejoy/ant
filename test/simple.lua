dofile "libs/init.lua"

require "scintilla"

local bgfx = require "bgfx"

local inputmgr = require "inputmgr"
local mapiup = require "inputmgr.mapiup"
local elog = require "editor.log"

local rhwi = require "render.hardware_interface"
local scene = require "scene.util"

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

local input_queue = inputmgr.queue(mapiup, canvas)

local function init()
	local fbw, fbh = 1280, 720
	rhwi.init(iup.GetAttributeData(canvas,"HWND"), fbw, fbh)
	local module_description_file = "mem://simple.module"
	fs_util.write_to_file(module_description_file, [[modules = {"test/system/simple_system.lua"}]])
	scene.start_new_world(input_queue, fbw, fbh, module_description_file)
end

dlg:showxy(iup.CENTER,iup.CENTER)
dlg.usersize = nil

init()

iup.MainLoop()
iup.Close()
bgfx.shutdown()
