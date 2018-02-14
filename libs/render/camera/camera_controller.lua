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
	local last_x = message.motion_x
	local last_y = message.motion_y

	message.motion_xy = {x = x, y = y}
	message.cb.motion = function (msg_comp, camera)
		local states = msg_comp.states
		if states.buttons.LEFT then
			local delta_x = x - last_x
			local delta_y = y - last_y
		end
	end

	message.motion_x = x
	message.motion_y = y
	message.motion_last_x = last_x
	message.motion_last_y = last_y
end

function message:keypress(c, p)
	print(string.format("keypress, char = %d, press = %d", char, is_press))
	message.cb.keypress = function()

	end
end

--[@
local cb_comp = ecs.component "cb_comp"{}

function cb_comp:init()
	cb_comp.cb = {}
end

--@]

--[@
local camera_controller_system = ecs.system "camera_controller"
camera_controller_system.singleton "math3d"
camera_controller_system.singleton "message_component"
camera_controller_system.singleton "cb_comp"

camera_controller_system.depend "iup_message"

function camera_controller_system:init()
	self.message_component.msg_observers:add(message)
	message.cb = self.cb_comp.cb
end

function camera_controller_system:update()
	ru.for_each_comp(world, {"view_tranfrosm"},
	function (entity)
		local vt = entity.view_tranfrosm
		if message.button_event ~= nil then
		end
		
		if message.motion_event ~= nil then
		end
		
	end)
end
--@]