local ecs = ...
local world = ecs.world
local w = world.w
local gizmo		= ecs.require "gizmo.gizmo"
local iom		= ecs.require "ant.objcontroller|obj_motion"
local irq		= ecs.require "ant.render|render_system.renderqueue"
local math3d	= require "math3d"
local mathpkg	= import_package "ant.math"
local mc		= mathpkg.constant
local timer		= ecs.require "ant.timer|timer_system"
local camera_sys = ecs.system "camera_system"
local global_data = require "common.global_data"
function camera_sys:init_world()
end

function camera_sys:entity_ready()
end

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

local animation = {
	running			= false,
	totoal_time		= 0.5,
	current_time	= 0,
}

local function on_key(key, press)
	if global_data.camera_lock then
		return
	end
	local pressed = press == 1 or press == 2
	if not pressed then -- or not rotate_mode
		return
	end
	local pan = false
	if key == "A" or key == "D" or key == "W" or key == "S" or key == "F" then
		pan = true
	end
	if not pan then
		return
	end
	local mq = w:first("main_queue camera_ref:in render_target:in")
	local ce<close> = world:entity(mq.camera_ref, "scene:update")
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
	elseif key == "F" and press == 1 then
		world:pub {"LookAtTarget", nil, true}
	end
	if newpos then
		iom.set_position(ce, newpos)
		world:pub {"camera", "move"}
	end
end

local function on_middle_mouse(dx, dy)
	local mq = w:first("main_queue camera_ref:in render_target:in")
	local ce<close> = world:entity(mq.camera_ref, "scene:update")
	local pos = iom.get_position(ce)
	local mat = math3d.matrix{s = iom.get_scale(ce), r = iom.get_rotation(ce), t = pos}
	local xdir = math3d.normalize(math3d.index(mat, 1))
	local ydir = math3d.normalize(math3d.index(mat, 2))
	local dir = math3d.add(math3d.mul(xdir, dx), math3d.mul(ydir, -dy))
	iom.set_position(ce, math3d.add(pos, math3d.mul(dir, 0.02 * move_speed * camera_speed)))
	world:pub {"camera", "move"}
end

local shift_down = false
local function on_right_mouse(dx, dy)
	local mq = w:first("main_queue camera_ref:in render_target:in")
	local ce<close> = world:entity(mq.camera_ref, "scene:update")
	local delta_yaw = dx * rotate_speed-- * camera_speed
	local delta_pitch = dy * rotate_speed
	local rad = math3d.tovalue(math3d.quat2euler(iom.get_rotation(ce)))
	local yaw = rad[2] - delta_yaw
	local pitch = rad[1] - delta_pitch
	-- min/max pitch
	if pitch > 1.47 then
		pitch = 1.47
	elseif pitch < -1.47 then
		pitch = -1.47
	end
	local rot = math3d.quaternion{pitch, yaw, 0}
	iom.set_rotation(ce, rot)
	if shift_down then
		local cam_pos = iom.get_position(ce)
		local target_pos = mc.ZERO
		if animation.target then
			target_pos = math3d.vector(animation.target)
		end
		local dist = -1.0 * math3d.length(math3d.sub(cam_pos, target_pos))
		iom.set_position(ce, math3d.muladd(dist, math3d.todirection(rot), target_pos))
	end
	world:pub {"camera", "rotation"}
end

local function on_wheel(delta)
	local mq = w:first("main_queue camera_ref:in render_target:in")
	local ce<close> = world:entity(mq.camera_ref, "scene:update")
	local dt = delta * zoom_speed * move_speed * camera_speed
	local pos = iom.get_position(ce)
	local zdir = math3d.index(math3d.matrix{s = iom.get_scale(ce), r = iom.get_rotation(ce), t = pos}, 3)
	iom.set_position(ce, math3d.add(pos, math3d.mul(math3d.normalize(zdir), dt)))
	world:pub {"camera", "zoom"}
end

local key_mb             = world:sub {"keyboard"}
local mouse_mb           = world:sub {"mouse"}
local event_gesture      = world:sub {"gesture", "pinch"}
local smooth_lookat_mb   = world:sub {"SmoothLookAt"}
local event_camera_speed = world:sub {"camera_controller", "move_speed"}
local lock_camera_mb     = world:sub {"LockCamera"}
local lock_camera
local function do_animation()
	if not animation.running then
		return true
	end
	local mq = w:first("main_queue camera_ref:in render_target:in")
	local ce<close> = world:entity(mq.camera_ref, "scene:update")
	if not animation.from_rot then
		local target = math3d.vector(animation.target)
		animation.from_rot = math3d.ref(iom.get_rotation(ce))
		animation.to_rot = math3d.ref(math3d.quaternion(math3d.transpose(math3d.lookat(iom.get_position(ce), target, math3d.vector(0.0, 1.0, 0.0)))))
		animation.from_pos = math3d.ref(iom.get_position(ce))
		animation.to_pos = math3d.ref(math3d.muladd(animation.dist, math3d.normalize(math3d.sub(iom.get_position(ce), target)), target))
	end
	local delta_time = timer.delta() * 0.001
	animation.current_time = animation.current_time + delta_time
	local ratio = animation.current_time / animation.totoal_time
	if ratio > 1.0 then
		ratio = 1.0
		animation.running = false
	end
	iom.set_rotation(ce, math3d.slerp(animation.from_rot, animation.to_rot, ratio))
	iom.set_position(ce, math3d.lerp(animation.from_pos, animation.to_pos, ratio))
	if not animation.running then
		animation.current_time = 0
		animation.from_rot = nil
		animation.to_rot = nil
		animation.from_pos = nil
		animation.to_pos = nil
	end
end

function camera_sys:handle_input()
	for _, lock in lock_camera_mb:unpack() do
		lock_camera = lock
	end
	if not do_animation() or lock_camera then
		return
	end

	for _, t, d in smooth_lookat_mb:unpack() do
		animation.target = t
		animation.dist = d
		animation.running = true
	end

	for _, _, speed in event_camera_speed:unpack()  do
		camera_speed = speed
	end

	for _, what, e in event_gesture:unpack() do
		on_wheel(e.velocity)
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

	for _, key, press, status in key_mb:unpack() do
		if key == "LeftShift" then
			shift_down = (press == 1 or press == 2)
		end
		on_key(key, press)
	end
end
