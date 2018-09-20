dofile "libs/init.lua"

local editor_mainwindow = require "editor.controls.window"
local rhwi = require "render.hardware_interface"
local bgfx = require "bgfx"
local scene = require "scene.util"

editor_mainwindow:run {
	init_op = function (nwh, fbw, fbh, iq)
		rhwi.init(nwh, fbw, fbh)
		return scene.start_new_world(iq, fbw, fbh, {"test_world.module", "engine.module", "editor.module"})
	end,
	shutdown_op = function ()
		bgfx.shutdown()
	end,

	fbw=1024, fbh=768,
}
