--luacheck: globals iup import
dofile "libs/init.lua"

local mainwin = require "test.samples.PVPScene.mainwindow"
mainwin:run {
	fbw=1024, fbh=768,
}
