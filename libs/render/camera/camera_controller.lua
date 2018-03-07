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

local point = {}; point.__index = point
function point.new(x, y) return setmetatable({x = x, y = y}, point) end
function point:__add(o) return point.new(self.x + o.x, self.y + o.y) end
function point:__sub(o) return point.new(self.x - o.x, self.y - o.y) end
function point:__mul(s) return point.new(self.x*s, self.y*s) end

function message:button(btn, p, x, y)
	message.xy = point.new(x, y)

end

function message:motion(x, y)
	--print(string.format("motion x = %d, y = %d", x, y))

	local last_xy = message.xy	
	local xy = point.new(x, y)
	message.xy = xy

	message.cb.motion = function (msg_comp, vt, math_stack, vp)
		local states = msg_comp.states
		local bs = states.buttons

		if (bs.LEFT or bs.RIGHT) and last_xy then
			local delta = (xy - last_xy)
			local zdir = vt.direction

			if message.yaw == nil then
				message.yaw = 0
				message.pitch = 0
			end

			local speed = 0.1
			message.yaw = message.yaw + (delta.x * speed)
			message.pitch = message.pitch + (delta.y * speed)

			local function limit(v, min, max)
				if v > max then v = max end
				if v < min then v = min end
				return v
			end

			message.pitch = limit(message.pitch, -89.9, 89.9)

			local xdir = {1, 0, 0, 0}
			local ydir = {0, 1, 0, 0}			
			local zdir_tmp = {0, 0, 1, 0}
			math_stack(zdir, 
						{type = "quat", axis = ydir, angle = {message.yaw}}, 
						{type = "quat", axis = xdir, angle = {message.pitch}}, "*", 
						{0, 0, 1, 0}, "*=")			
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

			local ydir = {0, 1, 0, 0}
			local xdir = {1, 0, 0, 0}

			if c == "LEFT" then
				math_stack(zdir, {type = "quat", axis = ydir, angle = {-1}}, zdir, "*=")				
			elseif c == "RIGHT" then
				math_stack(zdir, {type = "quat", axis = ydir, angle = {1}}, zdir, "*=")
			elseif c == "UP" then
				math_stack(zdir, {type = "quat", axis = xdir, angle = {-1}}, zdir, "*=")
			elseif c == "DOWN" then
				math_stack(zdir, {type = "quat", axis = xdir, angle = {1}}, zdir, "*=")
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