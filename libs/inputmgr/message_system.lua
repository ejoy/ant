local ecs = ...

local world = ecs.world
local bgfx = require "bgfx"
--[@
local message = {}

function message:resize(w, h)
	print("RESIZE", w, h)
	self.viewport.width = w
	self.viewport.height = h
	bgfx.set_view_rect(0, 0, 0, w, h)
	bgfx.reset(w, h, "v")
end

function message:button(...)
	print("BUTTON", ...)
end
--@]

--[@
local iup_message = ecs.system "iup_message"
iup_message.singleton "viewport"

function iup_message:update()
	for idx, msg, v1,v2,v3 in pairs(world.args.mq) do
		local f = message[msg]
		if f then
			f(self,v1,v2,v3)
		end
	end
end
--@]