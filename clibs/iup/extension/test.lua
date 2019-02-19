local iup = require "iuplua"

local iupex = require "iupextension"

local img = iupex.icon("iup.exe", "large")

local miandlg = iup.dialog {
	iup.label{ image = img, title = "icon" },
	title = "exeicon",
	size = "HALFxHALF",
}

miandlg:showxy(iup.CENTER,iup.CENTER)

iup.MainLoop()
iup.Close()
