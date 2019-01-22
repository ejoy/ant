local ecs = ...
local world = ecs.world

ecs.import "ant.inputmgr"

local objutil = require "util"
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

	local hit = {}
	objctrller.bind_tigger("hitstart", function (event)
		hit[1], hit[2] = event.x, event.y		
		hit.enable = true
	end)
	objctrller.bind_tigger("hitend", function()
		hit.enable = false
	end)

	objctrller.bind_constant("move_forward", function (event, value)
		if hit.enable then
			objutil.move(camera, 0, 0, calc_step(speed_persecond, timer.delta * 0.001))
		end
	end)
	objctrller.bind_constant("move_backward", function (event, value) 
		if hit.enable then
			objutil.move(camera, 0, 0, -calc_step(speed_persecond, timer.delta * 0.001))
		end
	end)
	objctrller.bind_constant("move_left", function (event, value)
		if hit.enable then
			objutil.move(camera, -calc_step(speed_persecond, timer.delta * 0.001), 0, 0)
		end
	end)
	objctrller.bind_constant("move_right", function (event, value) 
		if hit.enable then
			objutil.move(camera, calc_step(speed_persecond, timer.delta * 0.001), 0, 0)
		end
	end)
	objctrller.bind_constant("move_up", function (event, value) 
		if hit.enable then
			objutil.move(camera, 0, calc_step(speed_persecond, timer.delta * 0.001), 0)
		end
	end)
	objctrller.bind_constant("move_down", function (event, value) 
		if hit.enable then
			objutil.move(camera, 0, -calc_step(speed_persecond, timer.delta * 0.001), 0)
		end
	end)

	objctrller.bind_tigger("rotate", function (event)
		local dx, dy = event.x - hit[1], event.y - hit[2]
		local function pixel2angle(pixel)
			return pixel * 0.1
		end
		objutil.rotate(camera, pixel2angle(dy), pixel2angle(dx))
		hit[1], hit[2] = event.x, event.y
	end)	
end