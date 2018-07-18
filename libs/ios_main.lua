
dofile "libs/init.lua"
local rhwi = require "render.hardware_interface"
local scene = require "scene.util"
local inputmgr = require "inputmgr"

local iq = inputmgr.queue {
	BUTTON = "_,_,_,_,_",
	MOTION = "_,_,_",
}

local currentworld
function init(nativewnd, fbw, fbh)
	rhwi.init(nativewnd, fbw, fbh)
	currentworld = scene.start_new_world(iq, fbw, fbh, "test_world.module")
end

function input(msg, ...)
	iq:push(msg, ...)
end

function mainloop()
	currentworld.update()
end