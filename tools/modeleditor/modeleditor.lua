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

local anitime_slider = iup.val{
	MIN=0, MAX=1, VALUE="0.3",
	EXPAND="HORIZONTAL",
	mousemove_cb=function()
	end,
	button_press_cb=function()
	end,
	button_release_cb=function()
	end
}

local anitime_inputer = iup.text {
	VALUE="0",
	MAXSIZE="24x",
	ALIGNMENT="ARIGHT",
}

local animation_time = iup.vbox {
	iup.fill {},
	ani_text,
	iup.hbox {
		anitime_slider,
		anitime_inputer,
		iup.label {
			TITLE="Time(ms)",
		},	
		EXPAND="ON",
	},
	iup.fill {},
	ALIGNMENT = "ACENTER",
}

local ske_path_inputer = iup.text {
	ALIGNMENT="ALEFT",
	EXPAND ="ON",
	SIZE="120x0"
}

local ani_path_inputer = iup.text {
		ALIGNMENT="ALEFT",
		EXPAND ="ON",
		SIZE="120x0",
}

local anilist_ctrller = iup.list {
	SIZE="160x0",
	EXPAND="ON",
	"None1111111111111111111",								
}

local dlg = iup.dialog {
	iup.split {
		TITLE="first element",
		iup.split {
			ORIENTATION = "HORIZONTAL",
			canvas,
			animation_time,
		},
		-- attribute control
		iup.vbox {
			iup.tabs {
				TABTITLE0="Resource Files",
				iup.hbox {
					iup.vbox {
						iup.frame {
							TITLE="Skeleton",
							iup.hbox {
								ske_path_inputer,
								iup.button {
									TITLE="Browse",
									ALIGNMENT="ARIGHT",
									EXPAND ="ON",
								},
								EXPAND ="ON",
							},
						},
						iup.space {
							SIZE="0x5",
						},
						iup.frame {
							TITLE="Animation",
							iup.hbox {
								ani_path_inputer,
								iup.button {
									TITLE="Browse",
									ALIGNMENT="ARIGHT",
								},
								iup.fill {}
							},
						},
						iup.fill {},
					},
					iup.fill{},
					EXPAND="ON",
				},
				EXPAND="ON",
			},	
			iup.frame {
				TITLE = "Animation List",
				iup.vbox {
					anilist_ctrller,
					iup.fill{},
				},
				EXPAND="ON",
			},	
	
			ORIENTATION = "HORIZONTAL",			
		}
	},
	title = "Model Editor",	
}


function model_windows()
	return {
		anitime_slider=anitime_slider,
		anitime_inputer=anitime_inputer,
		ske_path=ske_path_inputer,
		ani_path=ani_path_inputer,
		anilist=anilist_ctrller,
	}
end

dlg:showxy(iup.CENTER, iup.CENTER)
dlg.usersize = nil

local function print_children(container)	
	
	local idx = 1
	while true do
		local ctrl = container[idx]
		if ctrl == nil then
			break
		end
		idx = idx + 1		
		print("title : ", ctrl.TITLE, ", NATURALSIZE : ", ctrl.NATURALSIZE)
		print_children(ctrl)
	end
end

print_children(dlg)

rhwi.init(iup.GetAttributeData(canvas, "HWND"), fbw, fbh)
local world = su.start_new_world(nil, fbw, fbh, {
	"engine.module",
})

if (iup.MainLoopLevel()==0) then
	iup.MainLoop()
	iup.Close()
end