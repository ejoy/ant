--luacheck: globals iup import
dofile "libs/init.lua"

local require = import and import(...) or require

local mainwin = require "test.samples.PVPScene.mainwindow"
mainwin:run {
	fbw=1024, fbh=768,
}
