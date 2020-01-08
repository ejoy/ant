local ecs = ...
local world = ecs.world

local timer 	= import_package "ant.timer"
local mathpkg 	= import_package "ant.math"
local ms 		= mathpkg.stack

local renderpkg = import_package "ant.render"
local camerautil= renderpkg.camera


local objctrller = require "objcontroller"
local camera_controller_system = ecs.system "camera_controller"

camera_controller_system.singleton "control_state"
camera_controller_system.require_system "objcontroller_system"

function camera_controller_system:post_init()
	local cameracomp = camerautil.main_queue_camera(world)
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
			ms(cameracomp.eyepos, cameracomp.eyepos, axis, {calc_step(speed_persecond, timer.deltatime * 0.005) * scale * 5}, "*+=")
		end
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
		if not hit.enable then
			return 
		end
		local dx, dy = event[1] - hit[1], event[2] - hit[2]
		local function pixel2radian(pixel)
			return pixel * 0.004
		end
		local right, up = ms:base_axes(cameracomp.viewdir)

		local q
		if dy ~= 0 then
			q = ms:quaternion(right, pixel2radian(dy))
		end
		if dx ~= 0 then
			local q1 = ms:quaternion(up, pixel2radian(dx))
			q = q and ms(q, q1, "*P") or q1
		end
		
		if q then
			ms(cameracomp.viewdir, q, cameracomp.viewdir, "*n=")
		end
		hit[1], hit[2] = event[1], event[2]
	end)	
end