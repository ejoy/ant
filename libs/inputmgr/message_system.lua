local ecs = ...

local world = ecs.world
local bgfx = require "bgfx"

--[@ message_component
local msg_comp = ecs.component "message_component"{}

function msg_comp:init()
	local message_observers = {}
	message_observers.__index = message_observers
	function message_observers:add(ob)
		table.insert(self, ob)
	end
	function message_observers:remove(ob)
		for i, v in ipairs(self) do
			if v == ob then
				table.remove(i)
				return
			end
		end
	end

	self.msg_observers = setmetatable({}, message_observers)	
end
--@]

--[@
local iup_message = ecs.system "iup_message"
iup_message.singleton "message_component"

function iup_message:update()
	local mq = world.args.mq 
	if mq then
		for _, msg, v1,v2,v3,v4,v5 in pairs(mq) do
			local observers = self.message_component.msg_observers
			for _, ob in ipairs(observers) do
				local action = ob[msg]
				if action then
					action(self,v1,v2,v3,v4,v5)
				end
			end
	
		end
	end

end
--@]