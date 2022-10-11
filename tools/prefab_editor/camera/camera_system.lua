local ecs = ...
local world = ecs.world
local w = world.w

local iom		= ecs.import.interface "ant.objcontroller|iobj_motion"
local irq		= ecs.import.interface "ant.render|irenderqueue"
local math3d	= require "math3d"
local mathpkg	= import_package "ant.math"
local mc		= mathpkg.constant

local event_camera_speed = world:sub{"camera_controller", "move_speed"}
local camera_init_eye_pos <const> = math3d.ref(math3d.vector(5, 5, 5, 1))
local camera_init_target <const> = math3d.ref(mc.ZERO_PT)
local camera_target				= math3d.ref(mc.ZERO_PT)
local camera_distance
local wheel_speed <const>		= 0.5
local pan_speed <const>			= 0.5
local rotation_speed <const>	= 1

local camera_sys	= ecs.system "camera_system"
function camera_sys:init_world()
	
end

function camera_sys:entity_ready()
	
end

local key_mb		= world:sub {"keyboard"}
local mouse_mb          = world:sub {"mouse"}
local mouse_wheel_mb    = world:sub {"mouse_wheel"}

local last_mousex
local last_mousey
local mousex
local mousey

local camera_speed = 1.0
local rotate_mode
local move_mode

local move_speed = 1.0
local zoom_speed = 0.5
local rotate_speed = 0.002

local function on_key(key, press)
	local pressed = press == 1 or press == 2
	if not pressed then -- or not rotate_mode
		return
	end
	local pan = false
	if key == "A" or key == "D" or key == "W" or key == "S" then
		pan = true
	end
	if not pan then
		return
	end
	local mq = w:first("main_queue camera_ref:in render_target:in")
	local ce<close> = w:entity(mq.camera_ref, "scene:update")
	local pos = iom.get_position(ce)
	local mat = math3d.matrix{s = iom.get_scale(ce), r = iom.get_rotation(ce), t = pos}
	local xdir = math3d.normalize(math3d.index(mat, 1))
	local zdir = math3d.normalize(math3d.index(mat, 3))
	local dt = move_speed * camera_speed
	local newpos
	if key == "A" then
		newpos = math3d.add(pos, math3d.mul(math3d.normalize(xdir), -dt))
	elseif key == "D" then
		newpos = math3d.add(pos, math3d.mul(math3d.normalize(xdir), dt))
	elseif key == "W" then
		newpos = math3d.add(pos, math3d.mul(math3d.normalize(zdir), dt))
	elseif key == "S" then
		newpos = math3d.add(pos, math3d.mul(math3d.normalize(zdir), -dt))
	--elseif key == "F" then
	end
	if newpos then
		iom.set_position(ce, newpos)
	end
end

local function on_middle_mouse(dx, dy)
	local mq = w:first("main_queue camera_ref:in render_target:in")
	local ce<close> = w:entity(mq.camera_ref, "scene:update")
	local pos = iom.get_position(ce)
	local mat = math3d.matrix{s = iom.get_scale(ce), r = iom.get_rotation(ce), t = pos}
	local xdir = math3d.normalize(math3d.index(mat, 1))
	local ydir = math3d.normalize(math3d.index(mat, 2))
	local dir = math3d.add(math3d.mul(xdir, dx), math3d.mul(ydir, -dy))
	iom.set_position(ce, math3d.add(pos, math3d.mul(dir, 0.02 * move_speed * camera_speed)))
end

local function on_right_mouse(dx, dy)
	local mq = w:first("main_queue camera_ref:in render_target:in")
	local ce<close> = w:entity(mq.camera_ref, "scene:update")
	local rad = math3d.tovalue(math3d.quat2euler(iom.get_rotation(ce)))
	local yaw = rad[2] - dx * rotate_speed-- * camera_speed
	local pitch = rad[1] - dy * rotate_speed-- * camera_speed
	-- min/max pitch : -85/85
	if pitch > 1.48 then
		pitch = 1.48
	elseif pitch < -1.48 then
		pitch = -1.48
	end
	iom.set_rotation(ce, math3d.quaternion{pitch, yaw, 0})
end

local function on_wheel(delta)
	local mq = w:first("main_queue camera_ref:in render_target:in")
	local ce<close> = w:entity(mq.camera_ref, "scene:update")
	local dt = delta * zoom_speed * move_speed * camera_speed
	local pos = iom.get_position(ce)
	local zdir = math3d.index(math3d.matrix{s = iom.get_scale(ce), r = iom.get_rotation(ce), t = pos}, 3)
	iom.set_position(ce, math3d.add(pos, math3d.mul(math3d.normalize(zdir), dt)))
	world:pub {"camera", "zoom"}
end

function camera_sys:handle_input()
	for _, _, speed in event_camera_speed:unpack()  do
		camera_speed = speed
	end
	for _, btn, state, x, y in mouse_mb:unpack() do
		if state == "DOWN" then
			last_mousex, last_mousey = x, y
			if btn == "RIGHT" then
				rotate_mode = true
			elseif btn == "MIDDLE" then
				move_mode = true
			end
		end
		if state == "MOVE" then
			if rotate_mode then
				mousex, mousey = x, y
				on_right_mouse(last_mousex - mousex, last_mousey - mousey)
				last_mousex, last_mousey = x, y
			elseif move_mode then
				mousex, mousey = x, y
				on_middle_mouse(last_mousex - mousex, last_mousey - mousey)
				last_mousex, last_mousey = x, y
			end
		end
		if state == "UP" then
			rotate_mode = false
			move_mode = false
		end
	end

	for _, delta in mouse_wheel_mb:unpack() do
		on_wheel(delta)
	end

	for _, key, press, status in key_mb:unpack() do
		on_key(key, press)
	end
end
