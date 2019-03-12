local ecs = ...
local world = ecs.world



ecs.import "ant.inputmgr"

local point2d = import_package "ant.math".point2d
local math3d = require "math3d"
local ms = import_package "ant.math".stack
local rhwi = import_package "ant.render".hardware_interface

local camera_controller_system = ecs.system "camera_controller"

camera_controller_system.singleton "message"
camera_controller_system.singleton "control_state"

camera_controller_system.depend "message_system"
camera_controller_system.depend "camera_init"

local function camera_move(forward_axis, position, dx, dy, dz)
	--ms(position, rotation, "b", position, "S", {dx}, "*+S", {dy}, "*+S", {dz}, "*+=")	
	local right_axis, up_axis = ms:base_axes(forward_axis)
	ms(position, 
		position, 
			right_axis, {dx}, "*+", 
			up_axis, {dy}, "*+", 
			forward_axis, {dz}, "*+=")
end

local function camera_reset(camera, target)
	ms(target, {0, 0, 0, 1}, "=")
	ms(camera.eyepos, {8, 8, -8, 1}, "=")
	ms(camera.viewdir, target, camera.eyepos, "-n=")
end

local function rotate_round_point(camera, point, dx, dy)
	local right, up = ms:base_axes(camera.viewdir)
	local forward = ms(
				{type="q", axis=up, radian={dx}}, 
				{type="q", axis=right, radian={dy}}, "*",	-- rotation quternion in stack
				camera.viewdir, "i*nP")	-- get view dir from point to camera position, than multipy with rotation quternion

	local distance = math.sqrt(ms(point, camera.eyepos, "-1.T")[1])	-- calculate 

	ms(camera.eyepos, point, forward, {distance}, '*+=',	--calculate new camera position: point + forward * distance
		camera.viewdir, forward, 'i=')	--reverse forward vector, make camera position to point
end

function camera_controller_system:init()	
	local camera_entity = world:first_entity("main_camera")

	local target = math3d.ref "vector"
	local camera = camera_entity.camera
	camera_reset(camera, target)

	local move_speed = 1
	local wheel_speed = 1
	local message = {}

	local last_xy
	function message:mouse_click(btn, p, x, y, status)
		last_xy = point2d(x, y)
	end

	function message:mouse_move(x, y, status)
		local xy = point2d(x, y)
		if last_xy then
			if status.RIGHT then
				local speed = move_speed * 0.1
				local delta = (xy - last_xy) * speed
				camera_move(camera.viewdir, target, -delta.x, delta.y, 0)
				camera_move(camera.viewdir, camera.eyepos, -delta.x, delta.y, 0)
			elseif status.LEFT then
				local speed = move_speed * 0.001
				local delta = (xy - last_xy) * speed
				rotate_round_point(camera, target, delta.x, delta.y)
				-- local distance = math.sqrt(ms(target, camera.eyepos, "-1.T")[1])
				-- camera_move(camera.viewdir, camera.eyepos, -delta.x, delta.y, 0)
				-- ms(camera.viewdir, target, camera.eyepos, "-n=")
				-- ms(camera.eyepos, target, {-distance}, camera.viewdir, "*+=")
			end
		end
		last_xy = xy
	end

	function message:mouse_wheel(x, y, delta)		
		camera_move(camera.viewdir, camera.eyepos, 0, 0, delta * wheel_speed)
	end

	function message:keyboard(code, press)
		if press and code == "r" then
			camera_reset(camera, target)
			return 
		end
	end

	function message:resize()
		rhwi.reset()
	end

	self.message.observers:add(message)
end
