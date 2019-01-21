local ecs = ...
local world = ecs.world
local schema = world.schema

local bgfx = require "bgfx"

--[@ message
schema:userdata "message"
local msg_comp = ecs.component "message"

function msg_comp:init()
	local self = {}
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

	self.observers = setmetatable({}, message_observers)
	return self
end
--@]

--[@
local msg_sys = ecs.system "message_system"
msg_sys.singleton "message"

function msg_sys:update()
	local mq = world.args.mq 
	if mq then
		for _, msg, v1,v2,v3,v4,v5 in pairs(mq) do
			local observers = self.message.observers
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