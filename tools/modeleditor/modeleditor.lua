dofile "libs/init.lua"

local rhwi = require "render.hardware_interface"
local su = require "scene.util"
local fu = require "filesystem.util"

local fbw, fbh = 800, 600

local canvas = iup.canvas {
	rastersize = fbw .. "x" .. fbh
}

local animation_time = iup.val{
	min=0, max=1,
	value="0.3", 
	-- mousemove_cb=fmousemove,
	-- button_press_cb=fbuttonpress,
	-- button_release_cb=fbuttonrelease
	EXPAND = "HORIZONTAL",
}

function animation_time:mousemove_cb()

end

function animation_time:button_press_cb()

end

function animation_time:button_release_cb()

end

local dlg = iup.dialog {
	iup.split {
		ORIENTATION = "HORIZONTAL",
		canvas,
		animation_time,
	},
	canvas,
	title = "Model Editor",	
}

dlg:showxy(iup.CENTER, iup.CENTER)
dlg.usersize = nil

rhwi.init(iup.GetAttributeData(canvas, "HWND"), fbw, fbh)

local modeleditor_modules = "mem://modeleditor.module"

local world = su.start_new_world(nil, fbw, fbh, {
	"engine.module",
})

if (iup.MainLoopLevel()==0) then
	iup.MainLoop()
	iup.Close()
end