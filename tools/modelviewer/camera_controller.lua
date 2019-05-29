local ecs = ...
local world = ecs.world

ecs.import "ant.inputmgr"

local mathpkg = import_package "ant.math"
local point2d = mathpkg.point2d
local ms = mathpkg.stack
local mu = mathpkg.util

local math3d = require "math3d"
local rhwi = import_package "ant.render".hardware_interface

local camera_controller_system = ecs.system "camera_controller"

camera_controller_system.singleton "message"
camera_controller_system.singleton "control_state"

camera_controller_system.depend "message_system"

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

local function rotate_round_point(camera, point, distance, dx, dy)	
	local right, up = ms:base_axes(camera.viewdir)

	if ms:is_parallel(mu.YAXIS, camera.viewdir, 0.05) then	
		ms(camera.viewdir,
		{type="q", axis=up, radian={dx}}, 
		camera.viewdir,
		"*n=")								-- get view dir from point to camera position, than multipy with rotation quternion
	else
		ms(camera.viewdir,
		{type="q", axis=up, radian={dx}}, 
		{type="q", axis=right, radian={dy}},	-- rotation quternion in stack
		"3**n=")								-- get view dir from point to camera position, than multipy with rotation quternion
	end
	ms(camera.eyepos, point, camera.viewdir, {distance}, '*-=')	--calculate new camera position: point - viewdir * distance
end

function camera_controller_system:init()	
	local camera_entity = world:first_entity("main_queue")

	local target = math3d.ref "vector"
	local camera = camera_entity.camera
	camera_reset(camera, target)

	local move_speed = 10
	local rotation_speed = 1
	local wheel_speed = 1
	local distance
	local last_xy
	local xdpi, ydpi = rhwi.dpi()

	local function convertxy(p2d)
		p2d.x = p2d.x / xdpi
		p2d.y = p2d.y / ydpi
		return p2d
	end
	
	local message = {}
	function message:mouse_click(_, press, x, y)
		last_xy = point2d(x, y)
		if press then
			distance = math.sqrt(ms(target, camera.eyepos, "-1.T")[1])
		end
	end

	function message:mouse_move(x, y, status)
		local xy = point2d(x, y)
		if last_xy then
			if status.RIGHT then
				local delta = convertxy(xy - last_xy) * move_speed
				camera_move(camera.viewdir, camera.eyepos, -delta.x, delta.y, 0)
				ms(target, camera.eyepos, camera.viewdir, {distance}, '*+=')
			elseif status.LEFT then
				local delta = convertxy(xy - last_xy) * rotation_speed
				rotate_round_point(camera, target, distance, delta.x, delta.y)
			end
		end
		last_xy = xy
	end

	function message:mouse_wheel(_, _, delta)		
		camera_move(camera.viewdir, camera.eyepos, 0, 0, delta * wheel_speed)
	end

	function message:keyboard(code, press)
		if press and code == "R" then
			camera_reset(camera, target)
			return 
		end
	end

	function message:resize(w, h)
		rhwi.reset(nil, w, h)
	end

	self.message.observers:add(message)
end
