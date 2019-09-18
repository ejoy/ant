local ecs = ...
local world = ecs.world

ecs.import "ant.inputmgr"

local math3d = require "math3d"

local mathpkg = import_package "ant.math"
local ms = mathpkg.stack

local renderpkg  = import_package "ant.render"
local camerautil = renderpkg.camera
local rhwi = import_package "ant.render".hardware_interface

local camera_temp_data = ecs.singleton "camera_temp_data"
function camera_temp_data:init()
	return {
		dx = 0,
		dy = 0,
		dz = 0,
	}
end

local camera_controller_system = ecs.system "camera_controller_2"

camera_controller_system.singleton "camera_temp_data"
camera_controller_system.singleton "message"
camera_controller_system.depend "message_system"

local function camera_reset(camera, target)
	ms(camera.eyepos, {0, 4, 8, 1}, "=")
	ms(camera.viewdir, {0, 2, 0, 1}, camera.eyepos, "-n=")
end

local function camera_move(forward_axis, position, dx, dy, dz)
	local right_axis, up_axis = ms:base_axes(forward_axis)
	ms(position, position, 
			right_axis, {dx}, "*+", 
			up_axis, {dy}, "*+", 
			forward_axis, {dz}, "*+=")
end

function camera_controller_system:init()	
	local mq = world:first_entity "main_queue"

	local camera = camerautil.get_camera(world, mq.camera_tag)
	camera_reset(camera)

	local data = self.camera_temp_data

	local move_speed = 0.5
	local lastx, lasty
	local xdpi, ydpi = rhwi.dpi()

	local message = {}

	function message:mouse(x, y, what, state)
		if what ~= "RIGHT" then
			return
		end
		if state == "MOVE" then
			local dx = (x - lastx) / xdpi * move_speed
			local dy = (y - lasty) / ydpi * move_speed
			local right, up = ms:base_axes(camera.viewdir)
			ms(camera.viewdir, {type="q", axis=up, radian={dx}}, {type="q", axis=right, radian={dy}}, "3**n=")
		end
		lastx, lasty = x, y
	end

	function message:keyboard(code, press)
		local delta = press == 1 and 1 or (press == 0 and -1 or 0)
		if code == "W" then
			data.dz = data.dz + delta
		elseif code == "S" then
			data.dz = data.dz - delta
		elseif code == "A" then
			data.dx = data.dx - delta
		elseif code == "D" then
			data.dx = data.dx + delta
		end
	end

	self.message.observers:add(message)
end

function camera_controller_system:update()
	local data = self.camera_temp_data
	if data.dx ~= 0 or data.dy ~= 0 or data.dz ~= 0 then
		local mq = world:first_entity "main_queue"
		local camera = camerautil.get_camera(world, mq.camera_tag)
		local speed = 0.5
		camera_move(camera.viewdir, camera.eyepos, speed * data.dx, speed * data.dy, speed * data.dz)
	end
end
