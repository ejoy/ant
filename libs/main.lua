dofile "libs/init.lua"

local fs = require "filesystem"
local vfs = require "vfs"
local cwd = fs.currentdir()
vfs.mount({	
	['engine/assets']=cwd .. "/assets", 
	['engine/libs'] = cwd .. "/libs"
}, cwd)

local editor_mainwindow = require "editor.controls.window"

editor_mainwindow:run {
	fbw=1024, fbh=768,
}
