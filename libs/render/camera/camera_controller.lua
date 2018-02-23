local ecs = ...
local ru = require "render.render_util"


local function move_along_direction(transform, step, speed)
	speed = speed or 1
	local thestep = step * speed;

	-- camera_transform.eye = stack(camera_transform.direction, {thestep, thestep, thestep, 1}, "*P", -- direction * theStep =>stackTop
	-- 							 camera_transform.eye, "+M")	-- stackTop + eye
end

local function move_horizontal_and_vertical(transform, step, speed)
	speed = speed or 1

end

local function rotate(transform, step, speed)
	speed = speed or 1
	local theStep = step * speed

end

local function update_camera_trans(camera, m, speed)
	--[@ rotate camera
	local btn = assert(m.button_event)
	local last_btn = m.button_last_event

	local motion = assert(m.motion_event)
	local last_motion = m.motion_last_event

	local keys = assert(m.keypress_event)
	local last_keys = m.keypress_last_event


	if btn.type == "LEFT" then
		local deltaX = last_motion and (motion.x - last_motion.x) or 0
		local deltaY = last_motion and (motion.y - last_motion.y) or 0

		if deltaX ~= 0 or deltaY ~= 0 then
			
		end
	end
	--@]
end

local message = {}

function message:button(b, p, x, y)
	message.cb.button = function (msg_comp, camera)
		if b == "LEFT" then
			
		end
	end
end

function message:motion(x, y)
	print(string.format("motion x = %d, y = %d", x, y))

	local point = {}; point.__index = point
	function point.new(x, y) setmetatable({x = x, y = y}, point) end
	function point:__add(o) return point.new(self.x + o.x, self.y + o.y) end
	function point:__sub(o) return point.new(self.x - o.x, self.y - o.y) end


	local last_xy = message.motion_xy
	message.last_xy = last_xy

	local xy = point.new(x, y)
	message.xy = xy

	message.cb.motion = function (msg_comp, vt, math3d)
		assert(math3d)
		local states = msg_comp.states
		if states.buttons.LEFT and last_xy then
			local delta = xy - last_xy
			
			--local camera_up = 
		end
	end
end

function message:keypress(c, p)
	print(string.format("keypress, char = %d, press = %d", char, is_press))
	message.cb.keypress = function()

	end
end

--[@
local camera_controller_system = ecs.system "camera_controller"
camera_controller_system.singleton "math3d"
camera_controller_system.singleton "message_component"

camera_controller_system.depend "iup_message"

function camera_controller_system:init()
	self.message_component.msg_observers:add(message)
	message.cb = {}
end

function camera_controller_system:update()
	ru.for_each_comp(world, {"view_tranfrosm"},
	function (entity)
		local vt = entity.view_tranfrosm
		
		for name, cb in message.cb do
			cb(self.message_component, vt, self.math3d)
		end
		
	end)

	message.cb = {}
end
--@]