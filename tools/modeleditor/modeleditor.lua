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
								iup.text {
									ALIGNMENT="ALEFT",
									EXPAND ="ON",
									SIZE="120x0"
								},
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
								iup.text {
									ALIGNMENT="ALEFT",
									SIZE="120x0"
								},
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
					iup.list {
						SIZE="160x0",
						EXPAND="ON",
						"None1111111111111111111",								
					},
					iup.fill{},
				},
				EXPAND="ON",
			},	
	
			ORIENTATION = "HORIZONTAL",			
		}
	},
	title = "Model Editor",	
}

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