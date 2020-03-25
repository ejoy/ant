local ecs = ...
local world = ecs.world

local math3d = require "math3d"
local rhwi = import_package "ant.render".hwi

local camera_controller_system = ecs.system "camera_controller2"

local function camera_move(forward_axis, position, dx, dy, dz)
	local right_axis, up_axis = math3d.base_axes(forward_axis)
	position.v = math3d.add(position, math3d.mul(forward_axis, dz))
	position.v = math3d.add(position, math3d.mul(up_axis, dy))
	position.v = math3d.add(position, math3d.mul(right_axis, dx))
end

local function get_camera()
	local mq = world:singleton_entity "main_queue"
	return world[mq.camera_eid].camera
end

local eventMouseLeft = world:sub {"mouse", "LEFT"}
local eventMouseRight = world:sub {"mouse", "RIGHT"}
local kMouseSpeed <const> = 0.5
local mouse_lastx, mouse_lasty
local dpi_x, dpi_y

local eventKeyboard = world:sub {"keyboard"}
local kKeyboardSpeed <const> = 0.5


function camera_controller_system:post_init()
	-- local camera = get_camera()
	-- camera.frustum.f = 100	--set far distance to 100
	-- camera_reset(camera)
	dpi_x, dpi_y = rhwi.dpi()

	--local message = {}
	--local w,s,a,d=0,0,0,0
	--function message:steering(code, press)
	--	if code == "W" then
	--		w = press
	--	elseif code == "S" then
	--		s = press
	--	elseif code == "A" then
	--		a = press
	--	elseif code == "D" then
	--		d = press
	--	end
	--	data.dz = w - s
	--	data.dx = d - a
	--end
	--self.message.observers:add(message)
end

local function can_rotate(camera)
	local lock_target = camera.lock_target
	return lock_target and lock_target.type ~= "rotate" or true
end

local function can_move(camera)
	local lock_target = camera.lock_target
	return lock_target and lock_target.type ~= "move" or true
end

function camera_controller_system:camera_control()
	local keyboard_dx, keyborad_dy, keyboard_dz = 0, 0, 0
	local camera = get_camera()
	
	if can_rotate(camera) then
		for _, e in ipairs{eventMouseLeft, eventMouseRight} do
			for _,_,state,x,y in e:unpack() do
				if state == "MOVE" and mouse_lastx then
					local ux = (x - mouse_lastx) / dpi_x * kMouseSpeed
					local uy = (y - mouse_lasty) / dpi_y * kMouseSpeed
					local right, up = math3d.base_axes(camera.viewdir)
					local qy = math3d.quaternion{axis=up, r=ux}
					local qx = math3d.quaternion{axis=right, r=uy}
					local q = math3d.mul(qy, qx)
					camera.viewdir.v = math3d.transform(q, camera.viewdir, 0)
				end
				mouse_lastx, mouse_lasty = x, y
			end
		end
	end
	if can_move(camera) then
		for _,code,press in eventKeyboard:unpack() do
			local delta = (press>0) and kKeyboardSpeed or 0
			if code == "W" then
				keyboard_dz = keyboard_dz + delta
			elseif code == "S" then
				keyboard_dz = keyboard_dz - delta
			elseif code == "A" then
				keyboard_dx = keyboard_dx - delta
			elseif code == "D" then
				keyboard_dx = keyboard_dx + delta
			elseif code == "Q" then
				keyborad_dy = keyborad_dy - delta
			elseif code == "E" then
				keyborad_dy = keyborad_dy + delta
			end
		end
		if keyboard_dx ~= 0 or keyborad_dy ~= 0 or keyboard_dz ~= 0 then
			camera_move(camera.viewdir, camera.eyepos, keyboard_dx, keyborad_dy, keyboard_dz)
		end
	end
end
