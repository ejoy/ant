
--dofile "libs/init.lua"
local rhwi = require "render.hardware_interface"
local scene = require "scene.util"
local inputmgr = require "inputmgr"
--local bgfx = require "bgfx"

local iq = inputmgr.queue {
	button = "_,_,_,_,_",
	motion = "_,_,_",
}

local ios_main = {}

local currentworld
function ios_main.init(nativewnd, fbw, fbh)
	rhwi.init(nativewnd, fbw, fbh)
	currentworld = scene.start_new_world(iq, fbw, fbh, "test_world_ios.module")

end

function ios_main.input(msg)
    --todo: handle multi-touches
    --msg contain "begin"/ "move" / "end" / "cancel"
    for k, v in ipairs(msg) do
--        print("get msg", k, v.msg, v.x, v.y)

        if v.msg == "begin" then
            iq:push("button", "RIGHT", true, v.x, v.y, {RIGHT = true})

        elseif v.msg == "move" then
            iq:push("motion", v.x, v.y, {RIGHT = true})

        --todo differentiate these two conditions
        elseif v.msg == "end" or v.msg == "cancel" then
            iq:push("button", "RIGHT", false, v.x, v.y, {RIGHT = false})
        end
    end
end

function ios_main.mainloop()
	currentworld.update()
end

return ios_main