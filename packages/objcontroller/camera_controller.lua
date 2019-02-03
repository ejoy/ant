local ecs = ...
local world = ecs.world

ecs.import "ant.inputmgr"

local timer = import_package "ant.timer"

local objutil = require "util"
local objctrller = require "objcontroller"
local camera_controller_system = ecs.system "camera_controller"

camera_controller_system.singleton "control_state"

camera_controller_system.depend "camera_init"
camera_controller_system.depend "objcontroller_system"

function camera_controller_system:init()
	local camera = world:first_entity("main_camera")
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

	objctrller.bind_constant("move_forward", function (scale)
		if hit.enable then
			objutil.move(camera, 0, 0, calc_step(speed_persecond, timer.deltatime * 0.001) * scale)
			return "handled"
		end
	end)
	
	objctrller.bind_constant("move_left", function (scale)
		if hit.enable then
			objutil.move(camera, calc_step(speed_persecond, timer.deltatime * 0.001) * scale, 0, 0)
			return "handled"
		end
	end)
	
	objctrller.bind_constant("move_up", function (scale) 
		if hit.enable then
			objutil.move(camera, 0, calc_step(speed_persecond, timer.deltatime * 0.001) * scale, 0)
			return "handled"
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