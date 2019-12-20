local ecs = ...
local world = ecs.world

ecs.import "ant.inputmgr"

local ms = import_package "ant.math".stack
local rhwi = import_package "ant.render".hardware_interface
local camerautil = import_package "ant.render".camera

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

local function camera_reset(camera)
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

local function get_camera()
	local mq = world:first_entity "main_queue"
	return camerautil.get_camera(world, mq.camera_tag)
end

function camera_controller_system:init()
	local camera = get_camera()
	camera.frustum.f = 100	--set far distance to 100
	camera_reset(camera)

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
	local data = self.camera_temp_data
	data.xdpi, data.ydpi = rhwi.dpi()
	data.eventMouseLeft = world:sub {"mouse", "LEFT"}
	data.eventKeyboard = world:sub {"keyboard"}
end

function camera_controller_system:update()
	local data = self.camera_temp_data
	local move_speed <const> = 0.5
	for _,_,state,x,y in data.eventMouseLeft:unpack() do
		if state == "MOVE" then
			local camera = get_camera()
			local dx = (x - data.lastx) / data.xdpi * move_speed
			local dy = (y - data.lasty) / data.ydpi * move_speed
			local right, up = ms:base_axes(camera.viewdir)
			ms(camera.viewdir, {type="q", axis=up, radian={dx}}, {type="q", axis=right, radian={dy}}, "3**n=")
		end
		data.lastx, data.lasty = x, y
	end
	for _,code,press in data.eventKeyboard:unpack() do
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
	if data.dx ~= 0 or data.dy ~= 0 or data.dz ~= 0 then
		local camera = get_camera()
		local speed = 0.5
		camera_move(camera.viewdir, camera.eyepos, speed * data.dx, speed * data.dy, speed * data.dz)
	end
end
