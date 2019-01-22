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

	objctrller.bind_constant("move_forward", function (event, value)
		camera_util.move(camera, 0, 0, calc_step(speed_persecond, timer.delta * 0.001))
	end)
	objctrller.bind_constant("move_backward", function (event, value) 
		camera_util.move(camera, 0, 0, -calc_step(speed_persecond, timer.delta * 0.001))
	end)
	objctrller.bind_constant("move_left", function (event, value)
		camera_util.move(camera, -calc_step(speed_persecond, timer.delta * 0.001), 0, 0)
	end)
	objctrller.bind_constant("move_right", function (event, value) 
		camera_util.move(camera, calc_step(speed_persecond, timer.delta * 0.001), 0, 0)
	end)
	objctrller.bind_constant("move_up", function (event, value) 
		camera_util.move(camera, 0, calc_step(speed_persecond, timer.delta * 0.001), 0)
	end)
	objctrller.bind_constant("move_down", function (event, value) 
		camera_util.move(camera, 0, -calc_step(speed_persecond, timer.delta * 0.001), 0)
	end)

	local hitpos = {0, 0}
	objctrller.bind_tigger("hitpos", function (event)
		hitpos[1], hitpos[2] = event.x, event.y
	end)

	objctrller.bind_tigger("rotate", function (event)
		local dx, dy = event.x - hitpos[1], event.y - hitpos[2]
		local function pixel2angle(pixel)
			return pixel * 0.1
		end
		camera_util.rotate(camera, pixel2angle(dx), pixel2angle(dy))
		hitpos[1], hitpos[2] = event.x, event.y
	end)	
end