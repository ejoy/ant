local ecs = ...
local world = ecs.world

ecs.import "ant.inputmgr"

local ms = import_package "ant.math".stack
local rhwi = import_package "ant.render".hardware_interface
local camerautil = import_package "ant.render".camera


local camera_controller_system = ecs.system "camera_controller_2"
camera_controller_system.step "camera_control"

camera_controller_system.singleton "message"
camera_controller_system.require_system "message_system"
camera_controller_system.require_system "render_system"

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

local eventMouseLeft = world:sub {"mouse", "LEFT"}
local kMouseSpeed <const> = 0.5
local mouse_lastx, mouse_lasty
local dpi_x, dpi_y

local eventKeyboard = world:sub {"keyboard"}
local kKeyboardSpeed <const> = 0.5
local keyboard_dx, keyborad_dy, keyboard_dz = 0, 0, 0

function camera_controller_system:init()
	local camera = get_camera()
	camera.frustum.f = 100	--set far distance to 100
	camera_reset(camera)
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

function camera_controller_system:update()
	for _,_,state,x,y in eventMouseLeft:unpack() do
		if state == "MOVE" then
			local camera = get_camera()
			local ux = (x - mouse_lastx) / dpi_x * kMouseSpeed
			local uy = (y - mouse_lasty) / dpi_y * kMouseSpeed
			local right, up = ms:base_axes(camera.viewdir)
			ms(camera.viewdir, {type="q", axis=up, radian={ux}}, {type="q", axis=right, radian={uy}}, "3**n=")
		end
		mouse_lastx, mouse_lasty = x, y
	end
	for _,code,press in eventKeyboard:unpack() do
		local delta = press == 1 and kKeyboardSpeed or (press == 0 and -kKeyboardSpeed or 0)
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
		local camera = get_camera()
		camera_move(camera.viewdir, camera.eyepos, keyboard_dx, keyborad_dy, keyboard_dz)
	end
end
