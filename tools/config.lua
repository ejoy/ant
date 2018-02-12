dofile "libs/init.lua"
require "iupluaimglib"

local toolset = require "editor.toolset"

local path = toolset.load_config()
local dlg

local function touch_dlg(touch)
	if touch then
		dlg.title = "Ant config (Not saved)"
	else
		dlg.title = "Ant config"
	end
end

local function path_edit(name, dir)
	local editor = iup.text {
		value = path[name] or "",
		expand="HORIZONTAL",
	}
	function editor:action(c, value)
		path[name] = value
		touch_dlg(true)
	end

	local button = iup.button {
		image = "IUP_FileOpen",
	}

	function button:action()
		local file = iup.filedlg {
			DIALOGTYPE = dir and "DIR" or "OPEN",
		}
		iup.Popup(file)
		if file.status ~= "-1" then
			path[name] = file.value
			editor.value = file.value
			touch_dlg(true)
		end
	end

	local ctrl = iup.hbox {
		iup.label {
			title = name,
			size = "50",
		},
		editor,
		button,
	}
	return ctrl
end

local function buttons()
	local open_home = iup.button {
		title = "HomeDir",
	}
	function open_home:action()
		os.execute("start " .. toolset.homedir)
	end
	local save = iup.button {
		title = "Save",
	}
	function save:action()
		toolset.save_config(path)
		touch_dlg()
	end

	return open_home, save
end

dlg = iup.dialog {
	iup.vbox {
		iup.frame {
			iup.vbox {
				path_edit "lua",
				path_edit "shaderc",
				path_edit ("shaderinc", true),	-- dir
			},
			title = "Path",
		},
		iup.hbox {
			gap = "8",
			iup.fill {},
			buttons(),
		},
	},
	margin = "4x4",
	size = "HALFxHALF",
	shrink="yes",
}

touch_dlg()

dlg:showxy(iup.CENTER,iup.CENTER)

iup.MainLoop()
iup.Close()
