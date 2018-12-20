-- luacheck: globals iup
-- luacheck: ignore self, ignore world

dofile "libs/init.lua"

require "iuplua"

local editor = require "editor"
local elog = require "editor.log"
local probeclass = require "editor.controls.assetprobebutton"

local fbw, fbh = 800, 600

local canvas = iup.canvas {
	rastersize = fbw .. "x" .. fbh
}

local ani_text = iup.label {
	TITLE = "Animation Time : 0(ms)",
	ALIGNMENT = "ACENTER",	
}

local anitime_slider = iup.val{	
	NAME="ANITIME_SLIDER",
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
		iup.toggle {
			NAME="AUTO_PLAY",
			TITLE="Play",
		},
		EXPAND="ON",
	},
	iup.fill {},
	ALIGNMENT = "ACENTER",
}

local function create_pathctrl(title, inputer_name, btn_name, assetview)
	local btn = iup.button {
		NAME=btn_name,
		TITLE="...",
		ALIGNMENT="ARIGHT",
	}

	local path_inputer = iup.text {
		NAME=inputer_name,
		ALIGNMENT="ALEFT",
		EXPAND ="ON",
		SIZE="120x0",
	}

	local probe = probeclass.new()
	probe:injust_assetview(assetview)
	probe:add_probe("asset", function (respath)
		path_inputer.VALUE = respath or ""
	end)

	return iup.frame {
		TITLE=title,
		iup.hbox {
			path_inputer,
			probe.view,
			btn,
			iup.fill {}
		},
	}
end

local assetviewclass = require "editor.controls.assetview"
local assetview = assetviewclass.new()

local ske_pathctrl = create_pathctrl("Skeleton", "SKE_PATH", "SKE_FINDER", assetview)
local ani_pathctrl = create_pathctrl("Animation", "ANI_PATH", "ANI_FINDER", assetview)
local mesh_pathctrl = create_pathctrl("Mesh", "SM_PATH", "SM_FINDER", assetview)

local listctrl = require "editor.controls.listctrl"
local anilist = listctrl.new {NAME="ANI_LIST"}

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
						iup.space { SIZE="0x5", },
						iup.toggle {
							NAME="SHOWBONES",
							TITLE="Show Bones",
							VALUE="OFF",
						},
						iup.space { SIZE="0x5", },
						iup.toggle {
							NAME="SHOWSAMPLE",
							TITLE="Show Sample Object",
							VALUE="ON",
						},
						iup.space { SIZE="0x5", },
						iup.toggle {
							NAME="SHOWSAMPLEBOUNDING",
							TITLE="Show Sample BoundingBox",
							VALUE="OFF",
						},
						iup.fill {},
					},
					iup.fill{},
					EXPAND="ON",
				},
				EXPAND="ON",
			},
			iup.tabs {
				assetview.view,
				anilist.list,
				TABTITLE0 = "Resources",
				TABTITLE1 = "Animation List",
				EXPAND="ON",
			},

			ORIENTATION = "HORIZONTAL",			
		}
	},
	title = "Model Editor",	
}

dlg:showxy(iup.CENTER, iup.CENTER)
dlg.usersize = nil

function main_dialog()
	return dlg
end

editor.run(fbw, fbh, canvas, {
	"tools.modeleditor.model_ed_system"
})