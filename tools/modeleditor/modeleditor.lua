-- luacheck: globals iup
-- luacheck: ignore self, ignore world

dofile "libs/init.lua"

local fs = require "filesystem"
local vfs = require "vfs"
local cwd = fs.currentdir()
vfs.mount({	
	['engine/assets']=cwd .. "/assets", 
	['engine/libs'] = cwd .. "/libs"
}, cwd)

require "iuplua"

local rhwi = require "render.hardware_interface"
local su = require "scene.util"


local inputmgr = require "inputmgr"
local mapiup = require "inputmgr.mapiup"

local elog = require "editor.log"

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
	NAME="DURATION",
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
			NAME="STATIC_DURATION",
			TITLE="Time(ms)",
		},	
		EXPAND="ON",
	},
	iup.fill {},
	ALIGNMENT = "ACENTER",
}

local function create_pathctrl(title)
	local btn = iup.button {
		TITLE="Browse",
		ALIGNMENT="ARIGHT",
	}

	local path_inputer = iup.text {
		ALIGNMENT="ALEFT",
		EXPAND ="ON",
		SIZE="120x0",
	}

	return iup.frame {
		TITLE=title,
		iup.hbox {
			path_inputer,
			btn,
			iup.fill {}
		},
	}
end

local ske_pathctrl = create_pathctrl("Skeleton")
local ani_pathctrl = create_pathctrl("Animation")
local mesh_pathctrl = create_pathctrl("Mesh")

local anilist_ctrller = iup.list {
	SIZE="160x0",
	EXPAND="ON",
	"None",
}

local dlg = iup.dialog {
	iup.split {		
		iup.split {
			ORIENTATION = "HORIZONTAL",
			canvas,
			iup.split {
				ORIENTATION = "HORIZONTAL",
				animation_time,
				elog.window,
			}			
		},
		-- attribute control
		iup.vbox {
			iup.tabs {
				TABTITLE0="Resource Files",
				iup.hbox {
					iup.vbox {
						ske_pathctrl,
						iup.space {	SIZE="0x5",	},
						ani_pathctrl,
						iup.space { SIZE="0x5", },
						mesh_pathctrl,
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

local function get_path_inputer(ctrl)
	return ctrl[1][1]
end

function model_windows()
	return {
		anitime_slider=anitime_slider,
		anitime_inputer=anitime_inputer,
		ske_path=get_path_inputer(ske_pathctrl),
		ani_path=get_path_inputer(ani_pathctrl),
		mesh_path=get_path_inputer(mesh_pathctrl),
		anilist=anilist_ctrller,
	}
end

dlg:showxy(iup.CENTER, iup.CENTER)
dlg.usersize = nil

-- local function print_children(container)	
	
-- 	local idx = 1
-- 	while true do
-- 		local ctrl = container[idx]
-- 		if ctrl == nil then
-- 			break
-- 		end
-- 		idx = idx + 1		
-- 		print("title : ", ctrl.TITLE, ", NATURALSIZE : ", ctrl.NATURALSIZE)
-- 		print_children(ctrl)
-- 	end
-- end

--print_children(dlg)

rhwi.init(iup.GetAttributeData(canvas, "HWND"), fbw, fbh, false)
local iq = inputmgr.queue(mapiup)
local eu = require "editor.util"
eu.regitster_iup(iq, canvas)
local world = su.start_new_world(iq, fbw, fbh, {
	"tools/modeleditor/model_ed_system.lua"
})

if (iup.MainLoopLevel()==0) then
	iup.MainLoop()
	iup.Close()
end