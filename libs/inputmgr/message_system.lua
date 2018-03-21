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
	self.states = {
		buttons = {},
		keys = {},
		button = function (self, b, p, x, y) self.buttons[b] = p end,
		keypress = function(self, c, p) 
			if c == nil then return end
			self.keys[c] = p 
		end,
	}
end
--@]

local function update_main_camera_viewrect(w, h)
	local camera = assert(world:first_entity("main_camera"))
	local vr = camera.view_rect
	vr.x, vr.y, vr.w, vr.h = 0, 0, w, h		
		-- will not consider camera view_rect not full cover framebuffer case
		-- local old_w, old_h = win.width, win.height
		-- local vr = camera.view_rect
		-- local newx = 0
		-- local newx_end = w
		-- if vr.x ~= 0 then
		-- 	newx = math.floor((vr.x / old_w) * w)
		-- 	newx_end = math.floor(((vr.x + vr.w) / old_w) * w)
		-- end

		-- local newy = 0
		-- local newy_end = h
		-- if vr.y ~= 0 then
		-- 	newy = math.floor((vr.y / old_h) * h)
		-- 	newy_end = math.floor(((vr.y + vr.h) / old_h) * h)
end

--[@
local message = {}
function message:resize(w, h)	
	local win = self.window
	win.width = w
	win.height = h
	update_main_camera_viewrect(w, h)
	bgfx.reset(w, h, "v")
end
--@]

--[@
local iup_message = ecs.system "iup_message"
iup_message.singleton "window"
iup_message.singleton "message_component"

function iup_message:init()
	local observers = self.message_component.msg_observers
	assert(observers)
	observers:add(message)
end

function iup_message:update()
	for _, msg, v1,v2,v3,v4,v5 in pairs(world.args.mq) do		
		local states = self.message_component.states
		local cb = states[msg]		
		if cb then
			cb(states,v1,v2,v3,v4,v5)
		end

		local observers = self.message_component.msg_observers
		for _, ob in ipairs(observers) do
			local action = ob[msg]
			if action then
				action(self,v1,v2,v3,v4,v5)
			end
		end

	end
end
--@]