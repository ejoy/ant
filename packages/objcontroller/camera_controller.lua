local ecs = ...
local world = ecs.world

ecs.import "ant.inputmgr"

local math3d = import_package "ant.math"
local point2d = math3d.point2d

local camera_util = import_package "ant.render".camera

local step = 0.01

local action_type = { 
	FORWARD = false, BACKWARD = false,
	LEFT = false, RIGHT = false,
	UPWARD = false, DOWNWARD = false,
	LEFTROT = false, RIGHTROT = false,
	ROTX = false, ROTY = false
}
local camera_controller_system = ecs.system "camera_controller"

camera_controller_system.singleton "message"
camera_controller_system.singleton "control_state"
camera_controller_system.singleton "timer"

camera_controller_system.depend "message_system"
camera_controller_system.depend "camera_init"

function camera_controller_system:init()	
	local camera = world:first_entity("main_camera")

	local move_speed = 1
	local message = {}

    local last_xy
	local button_status = {}
	-- luacheck: ignore self
	-- luacheck: ignore status
    function message:mouse_click(btn, p, x, y, status)
        button_status[btn] = p
        last_xy = point2d(x, y)
	end

	function message:mouse_move(x, y, status)
		local xy = point2d(x, y)
		if last_xy then
			if status.RIGHT then
				local speed = move_speed * 0.1
				local delta = (xy - last_xy) * speed	--we need to reverse the drag direction so that to rotate angle can reverse
				camera_util.rotate(camera, delta.x, delta.y)
			end 
		end

		last_xy = xy
	end

	local action_name_mappers = {
		-- right button
		r_a = "LEFT", r_d = "RIGHT",
		r_w = "FORWARD", r_s = "BACKWARD",
		r_c = "DOWNWARD", r_f = "UPWARD",		
		r_q = "LEFTROT", r_e = "RIGHTROT",
	}

	function message:keyboard(c, p, status)
		if c == nil then return end

		local name = nil
		if button_status.RIGHT then
			name = 'r_'
		elseif button_status.LEFT then
			name = 'l_'
		end

		local clower = c:lower()
		if name then
			name = name .. clower
			local t = action_name_mappers[name]
			if t then
				action_type[t] = p
			end	
		end

		local isctrl = status.CTRL
		if isctrl then
			if clower == "=" then
				step = math.min(1, step + 0.002)
			elseif clower == "-" then
				step = math.max(0.002, step - 0.002)				
			end	
		end		
	end

	self.message.observers:add(message)
end
-- make movement smooth 
function camera_controller_system:update()

	local camera = world:first_entity("main_camera")
	if camera then		
		local deltaTime = self.timer.delta
		
		local dx, dy, dz = 0, 0, 0
		if action_type.FORWARD then 
			dz = step
		elseif action_type.BACKWARD then
			dz = -step
		end

		if action_type.LEFT then 
			dx = -step			
		elseif action_type.RIGHT then 
			dx = step
		end

		if action_type.UPWARD then
			dy = step
		elseif action_type.DOWNWARD then
			dy = -step
		end

		if action_type.LEFTROT then 
			camera_util.rotate(camera, -step * deltaTime , 0)
		elseif action_type.RIGHTROT then 
			camera_util.rotate(camera,  step * deltaTime, 0)
		end 

		camera_util.move(camera, dx*deltaTime, dy*deltaTime, dz*deltaTime)
	end 
end