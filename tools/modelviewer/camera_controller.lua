local ecs = ...
local world = ecs.world

ecs.import "render.camera.camera_component"
ecs.import "render.components.general"
ecs.import "inputmgr.message_system"

local point2d = require "math.point2d"
local math3d = require "math3d"
local math = import_package "math"
local ms = math.stack

local camera_controller_system = ecs.system "camera_controller"

camera_controller_system.singleton "message"
camera_controller_system.singleton "control_state"

camera_controller_system.depend "message_system"
camera_controller_system.depend "camera_init"

local function camera_move(rotation, position, dx, dy, dz)
	ms(position, rotation, "b", position, "S", {dx}, "*+S", {dy}, "*+S", {dz}, "*+=")
end

local function camera_reset(camera, target)
	ms(target, {0, 0, 0, 1}, "=")
	ms(camera.position, {8, 8, -8, 1}, "=")
	ms(camera.rotation, target, camera.position, "-D=")
end

function camera_controller_system:init()	
	local camera = world:first_entity("main_camera")

	local target = math3d.ref "vector"
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
				camera_move(camera.rotation, target, -delta.x, delta.y, 0)
				camera_move(camera.rotation, camera.position, -delta.x, delta.y, 0)
			elseif status.LEFT then
				local speed = move_speed * 0.1
				local delta = (xy - last_xy) * speed
				local distance = math.sqrt(ms(target, camera.position, "-1.T")[1])
				camera_move(camera.rotation, camera.position, -delta.x, delta.y, 0)
				ms(camera.rotation, target, camera.position, "-D=")
				ms(camera.position, target, {-distance}, camera.rotation, "dn*+=")
			end
		end
		last_xy = xy
	end

	function message:mouse_wheel(delta, x, y)
		camera_move(camera.rotation, camera.position, 0, 0, delta * wheel_speed)
	end

	function message:keyboard(code, press)
		if press and code == "R" then
			camera_reset(camera, target)
			return 
		end
	end

	self.message.observers:add(message)
end
