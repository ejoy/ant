--luacheck:globals iup

dofile "libs/init.lua"
require "iuplua"

local editor = require "editor"
local elog = require "editor.log"
local fbw, fbh = 800, 600

local canvas = iup.canvas {
	rastersize = fbw .. "x" .. fbh
}

local dlg = iup.dialog {
	iup.split {
		canvas,
		elog.window
	}
}

dlg:showxy(iup.CENTER, iup.CENTER)

editor.run(800, 600, canvas, {
	"test.samples.geometry.geometry_generator"
})