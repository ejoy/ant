local ecs = ...
local world = ecs.world

ecs.import "ant.inputmgr"

local math3d = import_package "ant.math"

local camera_util = import_package "ant.render".camera

local objctrller = require "objcontroller"

-- local step = 0.01

-- local action_type = { 
-- 	FORWARD = false, BACKWARD = false,
-- 	LEFT = false, RIGHT = false,
-- 	UPWARD = false, DOWNWARD = false,
-- 	LEFTROT = false, RIGHTROT = false,
-- 	ROTX = false, ROTY = false
-- }
local camera_controller_system = ecs.system "camera_controller"

camera_controller_system.singleton "message"
camera_controller_system.singleton "control_state"
camera_controller_system.singleton "timer"

camera_controller_system.depend "message_system"
camera_controller_system.depend "camera_init"

local oc = objctrller.new {
 	move_forward = {
		{name="keyboard", key="W", press=true, state={},},
		{name="keyboard", key="w", press=true, state={},},
	},
	move_backward = {
		{name="keyboard", key="S", press=true, state={},},
		{name="keyboard", key="s", press=true, state={},},
	},
	move_left = {
		{name="keyboard", key="A", press=true, state={}},
		{name="keyboard", key="a", press=true, state={}},
	},
	move_right = {
		{name="keyboard", key="D", press=true, state={}},
		{name="keyboard", key="d", press=true, state={}},
	},
	move_up = {
		{name="keyboard", key="Q", press=true, state={}},
		{name="keyboard", key="q", press=true, state={}},
	},
	move_down = {
		{name="keyboard", key="E", press=true, state={}},
		{name="keyboard", key="e", press=true, state={}},
	},
	rotate = {
		{name="mouse_move", state={LEFT=true}},
	}
}

function camera_controller_system:init()	
	local camera = world:first_entity("main_camera")
	oc:bind_message_event(self.message)

	local timer = self.timer	
	local speed_persecond = 30
	local function calc_step(speed, delta)
		return speed * delta
	end

	oc:bind_tigger("move_forward", function (event)
		camera_util.move(camera, 0, 0, calc_step(speed_persecond, timer.delta * 0.001))
	end)
	oc:bind_tigger("move_backward", function (event) 
		camera_util.move(camera, 0, 0, -calc_step(speed_persecond, timer.delta * 0.001))
	end)
	oc:bind_tigger("move_left", function (event) 
		camera_util.move(camera, -calc_step(speed_persecond, timer.delta * 0.001), 0, 0)
	end)
	oc:bind_tigger("move_right", function (event) 
		camera_util.move(camera, calc_step(speed_persecond, timer.delta * 0.001), 0, 0)
	end)
	oc:bind_tigger("move_up", function (event) 
		camera_util.move(camera, 0, calc_step(speed_persecond, timer.delta * 0.001), 0)
	end)
	oc:bind_tigger("move_down", function (event) 
		camera_util.move(camera, 0, -calc_step(speed_persecond, timer.delta * 0.001), 0)
	end)

	local rotate_speed_persecond_degree = 30
	local last_rotate_event = nil
	oc:bind_tigger("rotate", function (event) 
		if last_rotate_event == nil then
			last_rotate_event = event
			return
		end

		local function sign(v)
			if v == 0 then
				return 0
			end
			if v > 0 then
				return 1
			end

			return -1			
		end

		local dx, dy = event.x - last_rotate_event.x, event.y - last_rotate_event.y

		local step = calc_step(rotate_speed_persecond_degree, timer.delta * 0.001)
		camera_util.rotate(camera, 
		sign(dx) * step,
		sign(dy) * step)

		last_rotate_event = event
	end)	
end
-- -- make movement smooth 
function camera_controller_system:update()
	oc:update()
end
-- function camera_controller_system:update()

-- 	local camera = world:first_entity("main_camera")
-- 	if camera then		
-- 		local deltaTime = self.timer.delta
		
-- 		local dx, dy, dz = 0, 0, 0
-- 		if action_type.FORWARD then 
-- 			dz = step
-- 		elseif action_type.BACKWARD then
-- 			dz = -step
-- 		end

-- 		if action_type.LEFT then 
-- 			dx = -step			
-- 		elseif action_type.RIGHT then 
-- 			dx = step
-- 		end

-- 		if action_type.UPWARD then
-- 			dy = step
-- 		elseif action_type.DOWNWARD then
-- 			dy = -step
-- 		end

-- 		if action_type.LEFTROT then 
-- 			camera_util.rotate(camera, -step * deltaTime , 0)
-- 		elseif action_type.RIGHTROT then 
-- 			camera_util.rotate(camera,  step * deltaTime, 0)
-- 		end 

-- 		camera_util.move(camera, dx*deltaTime, dy*deltaTime, dz*deltaTime)
-- 	end 
-- end