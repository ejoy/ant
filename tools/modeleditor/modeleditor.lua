-- luacheck: globals iup
-- luacheck: ignore self, ignore world

dofile "libs/init.lua"

require "iuplua"

local editor = require "editor"
local elog = require "editor.log"
local probeclass = require "editor.controls.assetprobe"
local fileinputer = require "tools.modeleditor.fileselectinputer"
local aniviewclass = require "tools.modeleditor.animationview"

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
		EXPAND="YES",
	},
	iup.fill {},
	ALIGNMENT = "ACENTER",  
}

local function create_pathctrl(title, name, assetview)
	local inputer = fileinputer.new({NAME=name})

	local probe = probeclass.new()
	probe:injust_assetview(assetview)	

	return iup.frame {
		TITLE=title,
		iup.hbox {
			inputer.view,
			probe.view,					
		},
	}
end

local assetviewclass = require "editor.controls.assetview"
local assetview = assetviewclass.new()

local ske_pathctrl = create_pathctrl("Skeleton", "SKEINPUTER", assetview)
local mesh_pathctrl = create_pathctrl("Mesh", "SMINPUTER", assetview)

local blendviewclass = require "tools.modeleditor.blendview"

local aniview = aniviewclass.new({NAME="ANIVIEW"})
aniview:injust_assetview(assetview)

local vectorviewclass = require "editor.controls.vectorview"

local ikview = iup.vbox {
	NAME = "IKVIEW",
	vectorviewclass.new({NAME="TARGET", TITLE="target"}).view,
	vectorviewclass.new({NAME="POLE_VECTOR", TITLE="pole vector"}).view,
	vectorviewclass.new({NAME="MID_AXIS", TITLE="mid axis"}).view,
	iup.gridbox {
		iup.label {TITLE = "weight:",},			iup.text {NAME="WEIGHT", MINSIZE="32x"},
		iup.label {TITLE="soften:"},			iup.text {NAME="SOFTEN", MINSIZE="32x"},
		iup.label {TITLE="twist angle:"},		iup.text {NAME="TWIST_ANGLE", MINSIZE="32x"},
		iup.label {TITLE="start joint index:"},	iup.text {NAME="START_JOINT", MINSIZE="32x"},
		iup.label {TITLE="mid joint index:"},	iup.text {NAME="MID_JOINT", MINSIZE="32x"},
		iup.label {TITLE="end joint index:"},	iup.text {NAME="END_JOINT", MINSIZE="32x"},
		NUMDIV = 2,
		NORMALIZESIZE ="BOTH",
		EXPANDCHILDREN="YES",
	},
	iup.button {
		NAME = "APPLY",
		TITLE= "Apply",
	}
}

local animation_expander = iup.expander {
	TITLE = "Animation",
	NAME = "ANIMATION",
	iup.tabs {
		TABTITLE0 = "Ani list",
		TABTITLE1 = "Blend",
		TABTITLE2 = "IK",
		aniview.view,
		blendviewclass.new({NAME="BLENDVIEW"}).view,
		ikview,
	}
}

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
			},			
		},
		-- attribute control
		iup.vbox {
			iup.tabs {
				TABTITLE0="Sample Model Resources",				
				iup.vbox {
					mesh_pathctrl,
					iup.space { SIZE="0x5", },
					ske_pathctrl,
					iup.space {	SIZE="0x5",	},
					animation_expander,
					iup.space { SIZE="0x5", },
					
					iup.expander {
						TITLE="Options",
						NAME = "OPTIONS",
						iup.vbox {
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
						}
					},
				},				
			},
			iup.tabs {
				assetview.view,
				anilist.view,
				TABTITLE0 = "Resources",
				TABTITLE1 = "Animation List",				
			},

			MINSIZE = "300x0",
		},		
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