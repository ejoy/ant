local ecs = ...

local world = ecs.world
local bgfx = require "bgfx"

--[@ message_component
local msg_comp = ecs.component "message_component"

function msg_comp:init()
	local message_observers = {}
	
	function message_observers:add(observer)
		table.insert(self, observer)
	end
	function message_observers:remove(observer)
		for i, v in ipairs(self) do
			if v == observer then
				table.remove(i)
				return
			end
		end
	end

	self.msg_observers = setmetatable({}, message_observers)
end
--@]

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
iup_message.singleton "message_component"

function iup_message:init()
	self.message_component.msg_observers:add(message)		
end

function iup_message:update()
	for idx, msg, v1,v2,v3,v4 in pairs(world.args.mq) do
		print("iup_message receive message : " .. msg)
		local observers = self.message_component.msg_observers
		for idx, observer in ipairs(observers) do
			local action_cb = observer[msg]
			if action_cb then
				action_cb(self,v1,v2,v3,v4)
			end
		end

	end
end
--@]