local ecs = ...
local ru = require "render.render_util"
local world = ecs.world
local math3d = require "math3d"

local message = {}

local function generate_basic_axis(ms, zdir, up)
	up = up or {0, 1, 0, 0}

	local xdir = ms(zdir, up, "xP")
	local ydir = ms(xdir, zdir, "xP")

	return xdir, ydir
end

local function rotate_vec(ms, v, axis, angle)
	ms(v, v, {type = "quat", axis = axis, angle = {angle}}, "*=")
end

local function move_position(ms, p, dir, speed)
	ms(p, p, dir, {speed}, "*+=")
end

function message:motion(x, y, status)
	--print(string.format("motion x = %d, y = %d", x, y))

	local point = {}; point.__index = point
	function point.new(x, y) return setmetatable({x = x, y = y}, point) end
	function point:__add(o) return point.new(self.x + o.x, self.y + o.y) end
	function point:__sub(o) return point.new(self.x - o.x, self.y - o.y) end
	function point:__mul(s) return point.new(self.x*s, self.y*s) end


	local last_xy = message.xy
	message.last_xy = last_xy

	local xy = point.new(x, y)
	message.xy = xy

	message.cb.motion = function (msg_comp, vt, math_stack, vp)
		local states = msg_comp.states
		local bs = states.buttons
		local ci = assert(vp.camera_info)

		if (bs.LEFT or bs.RIGHT) and last_xy then
			local delta = (xy - last_xy)
			local zdir = vt.direction
			-- local xdir, ydir = generate_basic_axis(math_stack, zdir)
			-- print("xdir = %s, ydir = %s", 
			-- 		math_stack(xdir, "V"),
			-- 		math_stack(ydir, "V"))

			local xmove_speed = delta.x > 0 and -ci.move_speed or ci.move_speed
			local ymove_speed = delta.y > 0 and -ci.move_speed or ci.move_speed

			local ydir = {0, 1, 0, 0}
			local xdir = {1, 0, 0, 0}

			math_stack(zdir, zdir, {type = "quat", axis = ydir, angle = {xmove_speed}}, "*=")
			math_stack(zdir, zdir, {type = "quat", axis = xdir, angle = {ymove_speed}}, "*=")

			--rotate_vec(math_stack, zdir, ydir, xmove_speed)

			-- if bs.LEFT then
			-- 	move_position(math_stack, eye, zdir, ymove_speed)
			-- end

			-- if bs.RIGHT then
			-- 	rotate_vec(math_stack, zdir, xdir, ymove_speed)
			-- end
			
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

				print("eye : ", vt.eye)
				print("zdir : ", vt.direction)
				print("default eye = ", table.concat(ci.default.eye, ","), 
					", default direction = ", table.concat(ci.default.direction, ","))
			end

			local states = assert(msg_comp.states)

			if states.buttons.RIGHT then
				local xdir, ydir = generate_basic_axis(math_stack, zdir)

				if c == "a" or c == "A" then					
					move_position(eye, xdir, move_step)
				elseif c == "d" or c == "D" then					
					move_position(eye, xdir, -move_step)
				elseif c == "w" or c == "W" then					
					move_position(eye, zdir, move_step)
				elseif c == "s" or c == "S" then					
					move_position(eye, zdir, -move_step)
				end
			end

			local ydir = {0, 1, 0, 0}
			local xdir = {1, 0, 0, 0}

			if c == "LEFT" then
				math_stack(zdir, zdir, {type = "quat", axis = ydir, angle = {1}}, "*=")				
			elseif c == "RIGHT" then
				math_stack(zdir, zdir, {type = "quat", axis = ydir, angle = {-1}}, "*=")
			elseif c == "UP" then
				math_stack(zdir, zdir, {type = "quat", axis = xdir, angle = {1}}, "*=")
			elseif c == "DOWN" then
				math_stack(zdir, zdir, {type = "quat", axis = xdir, angle = {-1}}, "*=")
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
		
	end)

	message.cb = {}
end
--@]