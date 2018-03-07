local ecs = ...
local ru = require "render.render_util"
local world = ecs.world
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

local function calc_rotate_angle_from_view_direction(ms, vr)
	-- the default view direction is (0, 0, 1, 0)
	local dir = ms(vr, "nT")
	assert(dir.type == 1 or dir.type == 2)	-- 1 for vec4, 2 for vec3

	local x, y, z = dir[1], dir[2], dir[3]
	local pitch = -math.asin(y)	
	local yaw = z ~= 0 and math.atan2(x, z) or 0	

	local function to_angle(rad)
		return rad * (180 / 3.1415926)
	end
	
	return to_angle(pitch), to_angle(yaw)
end

function message:motion(x, y)
	local last_xy = message.xy	
	local xy = point2d(x, y)
	message.xy = xy

	message.cb.motion = function (msg_comp, vt, math_stack, vp)
		local states = msg_comp.states
		local bs = states.buttons

		if (bs.LEFT or bs.RIGHT) and last_xy then
			local speed = vp.camera_info.move_speed * 0.1
			local delta = (last_xy - xy) * speed	--we need to reverse the drag direction so that to rotate angle can reverse
			local zdir = vt.direction	

			local euler = math_stack(zdir, "e", {type="e", delta.x, delta.y, 0}, "+T")
			assert(euler.type == 5)	--LINEAR_TYPE_EULER			
			local yaw, pitch, roll = euler[1], euler[2], euler[3]
			yaw = mu.limit(yaw, -179.9, 179.9)
			pitch = mu.limit(pitch, -89.9, 89.9)
			
			math_stack(zdir, {0, 0, 1, 0}, {type="e", yaw, pitch, roll}, "*=")

			-- local pitch, yaw = calc_rotate_angle_from_view_direction(math_stack, zdir)
			-- local speed = vp.camera_info.move_speed * 0.2	
			-- pitch = mu.limit(pitch + delta.y * speed, -89.9, 89.9)
			-- yaw = mu.limit(yaw + delta.x * speed, -179.9, 179.9)

			-- math_stack(zdir, 
			-- 			{type = "q", axis = "y", angle = {yaw}},
			-- 			{type = "q", axis = "x", angle = {pitch}},  "*",
			-- 			{0, 0, 1, 0}, "*=")
		end
	end
end

function message:keypress(c, p)
	if c == nil then return end

	message.cb.keypress = function(msg_comp, vt, math_stack, vp)
		if p then
			local move_step = vp.camera_info.move_speed
			local zdir = vt.direction
			local eye = vt.eye

			if c == "r" or c == "R" then
				local ci = vp.camera_info
				math_stack(	vt.eye, ci.default.eye, "=")
				math_stack( vt.direction, ci.default.direction, "=")
			end

			local states = assert(msg_comp.states)

			if states.buttons.RIGHT then
				local xdir, ydir = generate_basic_axis(math_stack, zdir)

				if c == "a" or c == "A" then					
					move_position(math_stack, eye, xdir, move_step)
				elseif c == "d" or c == "D" then					
					move_position(math_stack, eye, xdir, -move_step)
				elseif c == "w" or c == "W" then					
					move_position(math_stack, eye, zdir, move_step)
				elseif c == "s" or c == "S" then					
					move_position(math_stack, eye, zdir, -move_step)
				end			
			end

			if c == "LEFT" then
				rotate_vec(math_stack, zdir, "y", -1)				
			elseif c == "RIGHT" then
				rotate_vec(math_stack, zdir, "y", 1)				
			elseif c == "UP" then
				rotate_vec(math_stack, zdir, "x", -1)				
			elseif c == "DOWN" then
				rotate_vec(math_stack, zdir, "x", 1)				
			end
		end
	end
end

--[@
local camera_controller_system = ecs.system "camera_controller"
camera_controller_system.singleton "math_stack"
camera_controller_system.singleton "message_component"
camera_controller_system.singleton "viewport"

camera_controller_system.depend "iup_message"

function camera_controller_system:init()
	self.message_component.msg_observers:add(message)
	message.cb = {}
end

function camera_controller_system:update()
	ru.for_each_comp(world, {"view_transform", "frustum"},
	function (entity)
		local vt = entity.view_transform		
		for name, cb in pairs(message.cb) do
			cb(self.message_component, vt, self.math_stack, self.viewport)
			
		end

		--print("direction : ", vt.direction)
		
	end)

	message.cb = {}
end
--@]