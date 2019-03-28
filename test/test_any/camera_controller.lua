local ecs = ...
local world = ecs.world



ecs.import "ant.inputmgr"

local point2d = import_package "ant.math".point2d
local math3d = require "math3d"
local ms = import_package "ant.math".stack

local camera_controller_system = ecs.system "camera_controller"

camera_controller_system.singleton "message"
camera_controller_system.singleton "control_state"

camera_controller_system.depend "message_system"
-- camera_controller_system.depend "camera_init"

ecs.tag "test_remove_com"

ecs.component "camera_control"
	.scale "boolean"
	.move "boolean"

local function camera_move(forward_axis, position, dx, dy, dz)
	--ms(position, rotation, "b", position, "S", {dx}, "*+S", {dy}, "*+S", {dz}, "*+=")	
	local right_axis, up_axis = ms:base_axes(forward_axis)
	ms(position, 
		position, 
			right_axis, {dx}, "*+", 
			up_axis, {dy}, "*+", 
			forward_axis, {dz}, "*+=")
end



local function add_msg_callback(self)
	function get_camera()
		local camera_entity = world:first_entity("camera_control")
		-- local camera = camera_entity.camera
		return camera_entity
	end

	local target = math3d.ref "vector"
	ms(target, {0, 0, 0, 1}, "=")
	local move_speed = 1
	local wheel_speed = 1
	local message = {}

	local last_xy
	function message:mouse_click(btn, p, x, y, status)
		last_xy = point2d(x, y)
	end

	function message:mouse_move(x, y, status)
		local camera_entity = get_camera()
		if not camera_entity or not camera_entity.camera_control.move then
			return
		end
		local camera = camera_entity.camera
		local xy = point2d(x, y)
		if last_xy then
			if status.RIGHT then
				
				local speed = move_speed * 0.1
				local delta = (xy - last_xy) * speed
				camera_move(camera.viewdir, target, -delta.x, delta.y, 0)
				camera_move(camera.viewdir, camera.eyepos, -delta.x, delta.y, 0)
			elseif status.LEFT then
				local speed = move_speed * 0.1
				local delta = (xy - last_xy) * speed
				local distance = math.sqrt(ms(target, camera.eyepos, "-1.T")[1])
				camera_move(camera.viewdir, camera.eyepos, -delta.x, delta.y, 0)
				ms(camera.viewdir, target, camera.eyepos, "-n=")
				ms(camera.eyepos, target, {-distance}, camera.viewdir, "*+=")
			end
		end
		last_xy = xy
	end

	function message:mouse_wheel(x, y, delta)		
		local camera_entity = get_camera()
		if not camera_entity or not camera_entity.camera_control.scale then
			return
		end
		local camera = camera_entity.camera
		camera_move(camera.viewdir, camera.eyepos, 0, 0, delta * wheel_speed)
	end

	-- function message:keyboard(code, press)
	-- 	local camera = get_camera()
	-- 	if not camera.camera_control.move then
	-- 		return
	-- 	end
	-- 	if press and code == "R" then
	-- 		camera_reset(camera, target)
	-- 		return 
	-- 	end
	-- end

	self.message.observers:add(message)
end

function camera_controller_system:init()	
	add_msg_callback(self)
end


function camera_controller_system:update()
	for eid in world:each_new("camera_control") do
		local camera_entity = world[eid]
		local target = math3d.ref "vector"
		local camera = camera_entity.camera
		-- camera_reset(camera, target)
	end
end	
