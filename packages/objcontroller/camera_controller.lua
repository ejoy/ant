local ecs = ...
local world = ecs.world

ecs.import "ant.inputmgr"

local timer = import_package "ant.timer"
local mathpkg = import_package "ant.math"
local ms = mathpkg.stack
local mu = mathpkg.util

local objctrller = require "objcontroller"
local camera_controller_system = ecs.system "camera_controller"

camera_controller_system.singleton "control_state"
camera_controller_system.depend "objcontroller_system"

function camera_controller_system:init()
	local camera_entity = world:first_entity("main_queue")
	local cameracomp = camera_entity.camera
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

	local function step(axis, scale)
		--ms(cameracomp.eyepos, cameracomp.eyepos, axis, {calc_step(speed_persecond, timer.deltatime * 0.001) * scale}, "*+=")			
	end

	objctrller.bind_constant("move_forward", function (scale)
		if hit.enable then
			step(cameracomp.viewdir, scale)			
			return "handled"
		end
	end)
	
	objctrller.bind_constant("move_left", function (scale)
		if hit.enable then
			local xaxis = ms:base_axes(cameracomp.viewdir)
			step(xaxis, scale)
			return "handled"
		end
	end)
	
	objctrller.bind_constant("move_up", function (scale) 
		if hit.enable then
			local _, yaxis = ms:base_axes(cameracomp.viewdir)
			step(yaxis, scale)
			return "handled"
		end
	end)	

	objctrller.bind_tigger("rotate", function (event)
		local dx, dy = event.x - hit[1], event.y - hit[2]
		local function pixel2radian(pixel)
			return pixel * 0.001
		end

		local right, up = ms:base_axes(cameracomp.viewdir)
		local qy = ms:quaternion(right, pixel2radian(dy))
		local qx = ms:quaternion(up, pixel2radian(dx))
		ms(cameracomp.viewdir, qx, qy, "*", cameracomp.viewdir, "*n=")
		hit[1], hit[2] = event.x, event.y
	end)	
end