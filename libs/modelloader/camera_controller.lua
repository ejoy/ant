local ecs = ...
local world = ecs.world

ecs.import "render.math3d.math_component"
ecs.import "render.camera.camera_component"
ecs.import "render.components.general"
ecs.import "inputmgr.message_system"

local mu = require "math.util"
local cu = require "render.components.util"
local point2d = require "math.point2d"
local camera_util = require "render.camera.util"
local math3d = require "math3d"

local camera_controller_system = ecs.system "camera_controller"
camera_controller_system.singleton "math_stack"
camera_controller_system.singleton "message_component"
camera_controller_system.singleton "control_state"

camera_controller_system.depend "iup_message"
camera_controller_system.depend "camera_init"

local function camera_move(ms, rotation, position, dx, dy, dz)
	ms(position, rotation, "b", position, "S", {dx}, "*+S", {dy}, "*+S", {dz}, "*+=")
end

local function camera_reset(ms, camera, target)
	ms(target, {0, 0, 0, 1}, "=")
	ms(camera.position.v, {8, 8, -8, 1}, "=")
	ms(camera.rotation.v, target, camera.position.v, "-D=")
end

function camera_controller_system:init()
	local ms = self.math_stack
	local camera = world:first_entity("main_camera")

	local target = math3d.ref "vector"
	camera_reset(ms, camera, target)

	local move_speed = 1
	local message = {}

	local last_xy
	function message:button(btn, p, x, y, status)
		last_xy = point2d(x, y)
	end

	function message:motion(x, y, status)
		local xy = point2d(x, y)
		if last_xy then
			if status.RIGHT then
				local speed = move_speed * 0.1
				local delta = (xy - last_xy) * speed
				camera_move(ms, camera.rotation.v, target, -delta.x, delta.y, 0)
				camera_move(ms, camera.rotation.v, camera.position.v, -delta.x, delta.y, 0)
			elseif status.LEFT then
				local speed = move_speed * 0.1
				local delta = (xy - last_xy) * speed
				local distance = math.sqrt(ms(target, camera.position.v, "-1.T")[1])
				camera_move(ms, camera.rotation.v, camera.position.v, -delta.x, delta.y, 0)
				ms(camera.rotation.v, target, camera.position.v, "-D=")
				ms(camera.position.v, target, {-distance}, camera.rotation.v, "dn*+=")
			end
		end
		last_xy = xy
	end

	function message:wheel(delta, x, y, status)
		camera_move(ms, camera.rotation.v, camera.position.v, 0, 0, delta * move_speed)
	end

	function message:keypress(c, p, status)
		if c == nil then return end
		if not p then return end
		local c = c:upper()
		if c == "R" then
			camera_reset(ms, camera, target)
			return 
		end
	end

	self.message_component.msg_observers:add(message)
end
