local ecs = ...

local world = ecs.world
local bgfx = require "bgfx"

--[@ message_component
local msg_comp = ecs.component "message_component"{}

function msg_comp:init()
	local message_observers = {}
	message_observers.__index = message_observers
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
	self.states = {
		button = function (self, b, p, x, y) self.buttons[b] = p end,
		keypress = function(self, c, p) self.keys[c] = p end,
	}
end
--@]

--[@
local message = {}

function message:resize(w, h)	
	self.viewport.width = w
	self.viewport.height = h
	bgfx.set_view_rect(0, 0, 0, w, h)
	bgfx.reset(w, h, "v")
end
--@]

--[@
local iup_message = ecs.system "iup_message"
iup_message.singleton "viewport"
iup_message.singleton "message_component"

function iup_message:init()
	print("iup_message:init()")
	local observers = self.message_component.msg_observers
	assert(observers)
	observers:add(message)
end

function iup_message:update()
	for idx, msg, v1,v2,v3,v4 in pairs(world.args.mq) do
		print("iup_message receive message : " .. msg)
		local states = self.message_component.states
		local cb = states[msg]
		if cb then
			cb(states, v1, v2, v3, v4)
		end

		local observers = self.message_component.msg_observers
		for idx, observer in ipairs(observers) do
			local action = observer[msg]
			if action then
				action(self,v1,v2,v3,v4)
			end
		end

	end
end
--@]