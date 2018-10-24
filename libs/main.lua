dofile "libs/init.lua"

local editor_mainwindow = require "editor.controls.window"

editor_mainwindow:run {
	fbw=1024, fbh=768,
}
