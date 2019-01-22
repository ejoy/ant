local ecs = ...
local world = ecs.world

ecs.import "ant.inputmgr"

local camera_util = import_package "ant.render".camera
local objctrller = require "objcontroller"

local camera_controller_system = ecs.system "camera_controller"

camera_controller_system.singleton "control_state"
camera_controller_system.singleton "timer"

camera_controller_system.depend "camera_init"
camera_controller_system.depend "objcontroller_system"

function camera_controller_system:init()	
	local camera = world:first_entity("main_camera")

	local timer = self.timer	
	local speed_persecond = 30
	local function calc_step(speed, delta)
		return speed * delta
	end

	objctrller.bind_constant("move_forward", function (value)
		camera_util.move(camera, 0, 0, calc_step(speed_persecond, timer.delta * 0.001))
	end)
	objctrller.bind_constant("move_backward", function (value) 
		camera_util.move(camera, 0, 0, -calc_step(speed_persecond, timer.delta * 0.001))
	end)
	objctrller.bind_constant("move_left", function (value) 
		camera_util.move(camera, -calc_step(speed_persecond, timer.delta * 0.001), 0, 0)
	end)
	objctrller.bind_constant("move_right", function (value) 
		camera_util.move(camera, calc_step(speed_persecond, timer.delta * 0.001), 0, 0)
	end)
	objctrller.bind_constant("move_up", function (value) 
		camera_util.move(camera, 0, calc_step(speed_persecond, timer.delta * 0.001), 0)
	end)
	objctrller.bind_constant("move_down", function (value) 
		camera_util.move(camera, 0, -calc_step(speed_persecond, timer.delta * 0.001), 0)
	end)

	local rotate_speed_persecond_degree = 30
	local last_rotate_event = nil
	objctrller.bind_tigger("rotate", function (event) 
		if last_rotate_event == nil then
			last_rotate_event = event
			return
		end

		local function sign(v)
			if v == 0 then
				return 0
			end
			if v > 0 then
				return 1
			end

			return -1			
		end

		local dx, dy = event.x - last_rotate_event.x, event.y - last_rotate_event.y

		local step = calc_step(rotate_speed_persecond_degree, timer.delta * 0.001)
		camera_util.rotate(camera, 
		sign(dx) * step,
		sign(dy) * step)

		last_rotate_event = event
	end)	
end