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

local function clear_message(m)
	m.button_event = nil
	m.motion_event = nil
	m.keypress_event = nil
end

local message = {}

function message:button(b, p, x, y)
	--print(debug.traceback())
	print(string.format("button b = %d, is_press = %d, x = %d, y = %d", b, is_press, x, y))
	message.button_event = {
		btn_type = b,
		is_press = p,
		x = x,
		y = y,
	}
end

function message:motion(x, y)
	print(string.format("motion x = %d, y = %d", x, y))
	message.motion_event = {
		x = x, 
		y = y,
	}
end

function message:keypress(c, p)
	print(string.format("keypress, char = %d, press = %d", char, is_press))
	message.keypress_event = {
		char = c,
		is_press = p,
	}
end

--[@
local camera_controller_system = ecs.system "camera_controller"
camera_controller_system.singleton "math3d"
camera_controller_system.singleton "message_component"

camera_controller_system.depend "iup_message"

function camera_controller_system:init()
	self.message_component.msg_observers:add(message)
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

	clear_message(message)
end
--@]