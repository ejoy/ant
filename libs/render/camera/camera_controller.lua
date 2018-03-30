local ecs = ...
local world = ecs.world

local ru = require "render.util"
local cu = require "render.components.util"

local math3d = require "math3d"
local mu = require "math.util"
local point2d = require "math.point2d"

local message = {}

local function generate_basic_axis(ms, zdir, up)
	up = up or {0, 1, 0, 0}

	local xdir = ms(zdir, up, "xP")
	local ydir = ms(xdir, zdir, "xP")

	return xdir, ydir
end

local function rotate_vec(ms, v, axis, angle)	
	ms(v, {type = "quat", axis = axis, angle = {angle}}, v, "*=")
end

local function move_position(ms, p, dir, speed)
	ms(p, p, dir, {speed}, "*+=")
end

-- local function calc_rotate_angle_from_view_direction(ms, vr)
-- 	-- the default view direction is (0, 0, 1, 0)
-- 	local dir = ms(vr, "nT")
-- 	assert(dir.type == 1 or dir.type == 2)	-- 1 for vec4, 2 for vec3

-- 	local x, y, z = dir[1], dir[2], dir[3]
-- 	local pitch = -math.asin(y)	
-- 	local yaw = z ~= 0 and math.atan2(x, z) or 0	

-- 	local function to_angle(rad)
-- 		return rad * (180 / 3.1415926)
-- 	end
	
-- 	return to_angle(pitch), to_angle(yaw)
-- end

function message:motion(x, y)
	local last_xy = message.xy	
	local xy = point2d(x, y)
	message.xy = xy

	message.cb.motion = function (entity)
		local msg_comp = message.msg_comp		
		local ms = message.ms

		local states = msg_comp.states
		local bs = states.buttons


		if (bs.LEFT or bs.RIGHT) and last_xy then
			local speed = message.move_speed * 0.1
			local delta = (last_xy - xy) * speed	--we need to reverse the drag direction so that to rotate angle can reverse
			local rot = entity.rotation.v

			local rot_result = ms(rot, {delta.y, delta.x, 0, 0}, "+T")			
		
			rot_result[1] = mu.limit(rot_result[1], -89.9, 89.9)			
			ms(rot, rot_result, "=")

			-- local pitch, yaw = calc_rotate_angle_from_view_direction(ms, zdir)
			-- local speed = vp.camera_info.move_speed * 0.2	
			-- pitch = mu.limit(pitch + delta.y * speed, -89.9, 89.9)
			-- yaw = mu.limit(yaw + delta.x * speed, -179.9, 179.9)

			-- ms(zdir, 
			-- 			{type = "q", axis = "y", angle = {yaw}},
			-- 			{type = "q", axis = "x", angle = {pitch}},  "*",
			-- 			{0, 0, 1, 0}, "*=")
		end
	end
end

function message:keypress(c, p)
	if c == nil then return end

	message.cb.keypress = function(camera)
		if p then
			local msg_comp = message.msg_comp
			
			local ms = message.ms

			local move_step = message.move_speed
			local rot = camera.rotation
			local eye = camera.position.v

			local states = assert(msg_comp.states)

			local btn_st = states.buttons
			local nomouse = btn_st.RIGHT == nil and btn_st.LEFT == nil
			if nomoust and (c == "r" or c == "R") then
				ms(	eye, {0, 0, -10}, "=")
				ms( vt.rotation, {0, 0, 0}, "=")
				return 
			end

			if states.buttons.RIGHT then
				local zdir = ms(rot, "dP")
				local xdir, ydir = generate_basic_axis(ms, zdir)

				if c == "a" or c == "A" then					
					move_position(ms, eye, xdir, move_step)
				elseif c == "d" or c == "D" then					
					move_position(ms, eye, xdir, -move_step)
				elseif c == "w" or c == "W" then					
					move_position(ms, eye, zdir, move_step)
				elseif c == "s" or c == "S" then					
					move_position(ms, eye, zdir, -move_step)
				elseif c == "q" or c == "Q" then
					move_position(ms, eye, ydir, -move_step)
				elseif c == "e" or c == "E" then
					move_position(ms, eye, ydir, move_step)
				end
			end

			-- if c == "LEFT" then
			-- 	rotate_vec(ms, zdir, "y", -1)				
			-- elseif c == "RIGHT" then
			-- 	rotate_vec(ms, zdir, "y", 1)				
			-- elseif c == "UP" then
			-- 	rotate_vec(ms, zdir, "x", -1)				
			-- elseif c == "DOWN" then
			-- 	rotate_vec(ms, zdir, "x", 1)
			-- end
		end
	end
end

--[@
local camera_controller_system = ecs.system "camera_controller"
camera_controller_system.singleton "math_stack"
camera_controller_system.singleton "message_component"

camera_controller_system.depend "iup_message"

function camera_controller_system:init()
	self.message_component.msg_observers:add(message)
	message.cb = {}
	message.msg_comp = self.message_component
	message.ms = self.math_stack
	message.move_speed = 1
end

function camera_controller_system:update()
	local camera = world:first_entity("main_camera")
	if camera then
		for name, cb in pairs(message.cb) do
			cb(camera)
		end
	end
	
	message.cb = {}
end
--@]