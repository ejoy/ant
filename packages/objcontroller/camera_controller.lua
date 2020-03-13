local ecs = ...
local world = ecs.world

local timer = world:interface "ant.timer|timer"
local math3d = require "math3d"

local renderpkg = import_package "ant.render"
local camerautil= renderpkg.camera


local objctrller = require "objcontroller"
local camera_controller_system = ecs.system "camera_controller"

camera_controller_system.require_system "objcontroller_system"
camera_controller_system.require_interface "ant.timer|timer"
camera_controller_system.require_interface "ant.camera_controller|camera_motion"

local icm = world:interface "ant.camera_controller|camera_motion"

function camera_controller_system:post_init()
	local cameraeid = world:single_entity "main_queue".camera_eid
	local speed_persecond = 5
	local function calc_step(speed, delta)
		return speed * delta
	end

	local hit = {}
	objctrller.bind_tigger("hitstart", function (event)
		hit[1], hit[2] = event[1], event[2]
		hit.enable = true
	end)
	objctrller.bind_tigger("hitend", function()
		hit.enable = false
	end)

	local function step(axis, scale)
		if scale ~= 0 then
			return calc_step(speed_persecond, timer.delta() * 0.005) * scale * 5
		end
	end

	objctrller.bind_constant("move_forward", function (scale)
		if hit.enable then
			icm.move_toward(cameraeid, "forward", step(scale))
			return "handled"
		end
	end)
	
	objctrller.bind_constant("move_right", function (scale)
		if hit.enable then
			icm.move_toward(cameraeid, "right", step(scale))
			return "handled"
		end
	end)
	
	objctrller.bind_constant("move_up", function (scale) 
		if hit.enable then
			icm.move_toward(cameraeid, "up", step(scale))
			return "handled"
		end
	end)

	objctrller.bind_tigger("rotate", function (event)
		if not hit.enable then
			return 
		end
		local dx, dy = event[1] - hit[1], event[2] - hit[2]
		local function pixel2radian(pixel)
			return pixel * 0.004
		end
		
		icm.rotate(cameraeid, pixel2radian(dy), pixel2radian(dx))
		hit[1], hit[2] = event[1], event[2]
	end)
end
