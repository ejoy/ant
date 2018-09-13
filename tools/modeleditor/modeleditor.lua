-- luacheck: globals iup
-- luacheck: ignore self, ignore world

dofile "libs/init.lua"

local rhwi = require "render.hardware_interface"
local su = require "scene.util"

local fbw, fbh = 800, 600

local canvas = iup.canvas {
	rastersize = fbw .. "x" .. fbh
}

local ani_text = iup.label {
	TITLE = "Animation Time : 0(ms)",
	ALIGNMENT = "ACENTER",	
}

local animation_time_controller = iup.val{
	min=0, max=1,
	value="0.3", 	
	EXPAND = "HORIZONTAL",
}


function animation_time_controller:mousemove_cb()

end

function animation_time_controller:button_press_cb()

end

function animation_time_controller:button_release_cb()

end

local animation_time = iup.vbox {
	iup.fill {},
	ani_text,
	animation_time_controller,
	iup.fill {},
	ALIGNMENT = "ACENTER",
}

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
local world = su.start_new_world(nil, fbw, fbh, {
	"engine.module",
})

if (iup.MainLoopLevel()==0) then
	iup.MainLoop()
	iup.Close()
end