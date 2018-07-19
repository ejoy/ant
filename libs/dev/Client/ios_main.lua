
--dofile "libs/init.lua"
local rhwi = require "render.hardware_interface"
local scene = require "scene.util"
local inputmgr = require "inputmgr"
local ios_main = {}
local iq = inputmgr.queue {
	BUTTON = "_,_,_,_,_",
	MOTION = "_,_,_",
}

local currentworld
function ios_main.init(fbw, fbh)
	--rhwi.init(nativewnd, fbw, fbh)
	currentworld = scene.start_new_world(iq, fbw, fbh, "test_world.module")
end

function ios_main.input(msg, ...)
	iq:push(msg, ...)
end

function ios_main.mainloop()
    print("loop")
	currentworld.update()
end

return ios_main